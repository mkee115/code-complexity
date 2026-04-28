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
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

public class GitHubSearcher
{
    private static final String API = "https://api.github.com";
    private static final int PER_PAGE = 100;
    private static final int MAX_PAGES = 10;

    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();
    private final String token;

    public GitHubSearcher(String token)
    {
        this.token = token;
    }

    public static String readToken(Path tokenFile) throws IOException
    {
        return Files.readString(tokenFile).trim();
    }

    public List<Repo> search(String rawQuery) throws IOException, InterruptedException
    {
        CommitFilter commitFilter = CommitFilter.extract(rawQuery);
        String cleanedQuery = commitFilter.queryWithoutCommits();

        List<Repo> results = new ArrayList<>();

        for (int page = 1; page <= MAX_PAGES; page++)
        {
            String url = API + "/search/repositories?q=" + URLEncoder.encode(cleanedQuery, StandardCharsets.UTF_8)
                    + "&per_page=" + PER_PAGE + "&page=" + page;

            HttpResponse<String> response = send(url);
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

    private HttpResponse<String> send(String url) throws IOException, InterruptedException
    {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .header("Accept", "application/vnd.github+json")
                .header("X-GitHub-Api-Version", "2022-11-28");
        if (token != null && !token.isEmpty())
            builder.header("Authorization", "Bearer " + token);
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
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