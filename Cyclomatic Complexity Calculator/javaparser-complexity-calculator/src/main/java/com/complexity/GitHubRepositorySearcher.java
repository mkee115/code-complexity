package com.complexity;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class GitHubRepositorySearcher
{
    private static final String API = "https://api.github.com";
    private static final int PER_PAGE = 100;
    private static final int MAX_PAGES = 10;
    private static final LocalDate GITHUB_EPOCH = LocalDate.of(2008, 1, 1);
    private static final long API_DELAY_MS = 750;

    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final String token;

    public GitHubRepositorySearcher(String token)
    {
        this.token = token;
    }

    public static String readToken(Path tokenFile) throws IOException
    {
        return Files.readString(tokenFile).trim();
    }

    public List<SearchChunk> planChunks(String baseQuery, LocalDate createdBefore, int targetRepos)
            throws IOException, InterruptedException
    {
        List<SearchChunk> chunks = new ArrayList<>();
        LocalDate chunkEnd = createdBefore;
        int totalCollected = 0;
        int chunkNum = 0;

        while (totalCollected < targetRepos)
        {
            if (!chunkEnd.isAfter(GITHUB_EPOCH)) break;

            chunkNum++;
            int remaining = targetRepos - totalCollected;
            long maxDays = ChronoUnit.DAYS.between(GITHUB_EPOCH, chunkEnd);

            System.out.print("  Planning chunk " + chunkNum + "... ");

            int fullRangeCount = countResultsRaw(baseQuery + " created:" + GITHUB_EPOCH + ".." + chunkEnd);

            if (fullRangeCount == 0)
            {
                System.out.println("no results remaining, stopping.");
                break;
            }

            boolean lastPhase = remaining < 1000 || fullRangeCount < 1000;

            SearchChunk chunk;
            if (lastPhase)
            {
                int need = Math.min(remaining, fullRangeCount);
                chunk = findMinWindowMeetingTarget(baseQuery, chunkEnd, maxDays, need);
                System.out.println(chunk.expectedCount + " results between "
                        + chunk.startDate + " and " + chunk.endDate);
                chunks.add(chunk);
                totalCollected += chunk.expectedCount;
                break;
            }
            else
            {
                chunk = findMaxWindowUnderLimit(baseQuery, chunkEnd, maxDays, 1000);
                System.out.println(chunk.expectedCount + " results between "
                        + chunk.startDate + " and " + chunk.endDate);
                chunks.add(chunk);
                totalCollected += chunk.expectedCount;
                chunkEnd = chunk.startDate.minusDays(1);
            }
        }

        return chunks;
    }

    private SearchChunk findMaxWindowUnderLimit(String baseQuery, LocalDate chunkEnd,
            long maxDays, int limit) throws IOException, InterruptedException
    {
        long lo = 1, hi = maxDays;
        long bestDays = 1;

        while (lo <= hi)
        {
            long mid = (lo + hi) / 2;
            LocalDate testStart = chunkEnd.minusDays(mid);
            int count = countResultsRaw(baseQuery + " created:" + testStart + ".." + chunkEnd);

            if (count < limit)
            {
                bestDays = mid;
                lo = mid + 1;
            }
            else
            {
                hi = mid - 1;
            }
        }

        LocalDate chunkStart = chunkEnd.minusDays(bestDays);
        int finalCount = countResultsRaw(baseQuery + " created:" + chunkStart + ".." + chunkEnd);
        return new SearchChunk(chunkStart, chunkEnd, finalCount);
    }

    private SearchChunk findMinWindowMeetingTarget(String baseQuery, LocalDate chunkEnd,
            long maxDays, int need) throws IOException, InterruptedException
    {
        long lo = 1, hi = maxDays;
        long bestDays = maxDays;

        while (lo <= hi)
        {
            long mid = (lo + hi) / 2;
            LocalDate testStart = chunkEnd.minusDays(mid);
            int count = countResultsRaw(baseQuery + " created:" + testStart + ".." + chunkEnd);

            if (count >= need)
            {
                bestDays = mid;
                hi = mid - 1;
            }
            else
            {
                lo = mid + 1;
            }
        }

        LocalDate chunkStart = chunkEnd.minusDays(bestDays);
        int finalCount = countResultsRaw(baseQuery + " created:" + chunkStart + ".." + chunkEnd);
        return new SearchChunk(chunkStart, chunkEnd, finalCount);
    }

    private int countResultsRaw(String query) throws IOException, InterruptedException
    {
        Thread.sleep(API_DELAY_MS);
        String url = API + "/search/repositories?q=" + URLEncoder.encode(query, StandardCharsets.UTF_8)
                + "&per_page=1&page=1";

        HttpResponse<String> response = send(url);

        if (response.statusCode() == 422) return 0;

        if (response.statusCode() == 403 || response.statusCode() == 429)
        {
            System.err.println("\nRate limited, waiting 60s...");
            Thread.sleep(60_000);
            response = send(url);
        }

        if (response.statusCode() != 200)
            throw new IOException("Count request failed: " + response.statusCode() + " " + response.body());

        JsonNode root = json.readTree(response.body());
        return root.get("total_count").asInt();
    }

    public List<Repo> search(String rawQuery) throws IOException, InterruptedException
    {
        CommitFilter commitFilter = CommitFilter.extract(rawQuery);
        String cleanedQuery = commitFilter.queryWithoutCommits();

        List<Repo> results = new ArrayList<>();

        for (int page = 1; page <= MAX_PAGES; page++)
        {
            Thread.sleep(API_DELAY_MS);
            String url = API + "/search/repositories?q=" + URLEncoder.encode(cleanedQuery, StandardCharsets.UTF_8)
                    + "&per_page=" + PER_PAGE + "&page=" + page;

            HttpResponse<String> response = send(url);

            if (response.statusCode() == 403 || response.statusCode() == 429)
            {
                System.err.println("\nRate limited during search, waiting 60s...");
                Thread.sleep(60_000);
                response = send(url);
            }

            if (response.statusCode() != 200)
                throw new IOException("Search failed: " + response.statusCode() + " " + response.body());

            JsonNode root = json.readTree(response.body());
            JsonNode items = root.get("items");
            if (items == null || items.size() == 0) break;

            for (JsonNode item : items)
            {
                Repo repo = buildRepo(item);
                repo.commitCount = fetchCommitCount(repo.fullName);

                if (commitFilter.isActive() && !commitFilter.matches(repo.commitCount))
                    continue;

                if (!hasPomXml(repo.fullName))
                    continue;

                results.add(repo);
            }

            if (items.size() < PER_PAGE) break;
        }

        return results;
    }

    private Repo buildRepo(JsonNode item)
    {
        Repo r = new Repo();
        r.fullName = item.get("full_name").asText();
        r.cloneUrl = item.get("clone_url").asText();
        r.htmlUrl = item.get("html_url").asText();
        r.stars = item.get("stargazers_count").asInt();
        r.forks = item.get("forks_count").asInt();
        r.sizeKb = item.get("size").asInt();
        r.createdAt = item.get("created_at").asText();
        r.pushedAt = item.get("pushed_at").asText();
        r.language = item.hasNonNull("language") ? item.get("language").asText() : "";
        return r;
    }

    private int fetchCommitCount(String fullName) throws IOException, InterruptedException
    {
        String url = API + "/repos/" + fullName + "/commits?per_page=1";
        HttpResponse<String> response = send(url);
        if (response.statusCode() != 200) return -1;

        Optional<String> link = response.headers().firstValue("Link");
        if (link.isEmpty())
        {
            JsonNode arr = json.readTree(response.body());
            return arr.size();
        }

        Matcher m = Pattern.compile("[?&]page=(\\d+)>;\\s*rel=\"last\"").matcher(link.get());
        if (m.find()) return Integer.parseInt(m.group(1));
        return -1;
    }

    private boolean hasPomXml(String fullName) throws IOException, InterruptedException
    {
        String url = API + "/repos/" + fullName + "/contents/pom.xml";
        HttpResponse<String> response = send(url);
        return response.statusCode() == 200;
    }

    private HttpResponse<String> send(String url) throws IOException, InterruptedException
    {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .header("Accept", "application/vnd.github+json")
                .header("X-GitHub-Api-Version", "2022-11-28");
        if (token != null && !token.isEmpty())
            builder.header("Authorization", "Bearer " + token);
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    public static class SearchChunk
    {
        public final LocalDate startDate;
        public final LocalDate endDate;
        public final int expectedCount;

        public SearchChunk(LocalDate startDate, LocalDate endDate, int expectedCount)
        {
            this.startDate = startDate;
            this.endDate = endDate;
            this.expectedCount = expectedCount;
        }

        public String dateFilter()
        {
            return "created:" + startDate + ".." + endDate;
        }
    }

    public static class Repo
    {
        public String fullName;
        public String cloneUrl;
        public String htmlUrl;
        public int stars;
        public int forks;
        public int sizeKb;
        public String createdAt;
        public String pushedAt;
        public String language;
        public int commitCount;
    }

    private static class CommitFilter
    {
        private final String operator;
        private final Integer threshold;
        private final String cleanedQuery;

        private CommitFilter(String operator, Integer threshold, String cleanedQuery)
        {
            this.operator = operator;
            this.threshold = threshold;
            this.cleanedQuery = cleanedQuery;
        }

        static CommitFilter extract(String query)
        {
            Matcher m = Pattern.compile("commits:([<>]=?)(\\d+)").matcher(query);
            if (!m.find()) return new CommitFilter(null, null, query);
            String cleaned = m.replaceAll("").replaceAll("\\s+", " ").trim();
            return new CommitFilter(m.group(1), Integer.parseInt(m.group(2)), cleaned);
        }

        boolean isActive()
        {
            return operator != null;
        }

        String queryWithoutCommits()
        {
            return cleanedQuery;
        }

        boolean matches(int count)
        {
            if (count < 0) return false;
            return switch (operator)
            {
                case ">" -> count > threshold;
                case ">=" -> count >= threshold;
                case "<" -> count < threshold;
                case "<=" -> count <= threshold;
                default -> true;
            };
        }
    }
}
