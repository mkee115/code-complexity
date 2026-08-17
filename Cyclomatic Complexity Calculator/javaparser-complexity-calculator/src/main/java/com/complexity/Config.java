package com.complexity;

import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

/**
 * Runtime configuration for {@link ComplexityCalculator}, loaded from a
 * properties file so runs no longer require recompilation.
 *
 * The config file is resolved as: an explicit path passed as the first CLI
 * argument, else {@code config.properties} in the working directory, else
 * {@code config.properties} next to the module (discovered from the code
 * location), else the built-in defaults.
 *
 * Relative {@code output.dir} / {@code token.file} values are resolved against
 * the config file's directory (the module), NOT the working directory, so the
 * program produces output in the right place no matter where it is launched
 * from (IDE run, mvn exec:java, packaged jar, ...).
 *
 * Optional filters (language, star/fork/size/commit bounds, pushed-after) are
 * left empty in the file to mean "no filter".
 */
public class Config
{
    public final String runMode;          // LOCAL_PATH | GITHUB_REPO | GITHUB_SEARCH
    public final String localInput;       // LOCAL_PATH: file or directory
    public final String singleRepoUrl;    // GITHUB_REPO: clone URL

    public final String language;         // GitHub search filters (null = omit)
    public final Integer minStars;
    public final Integer minForks;
    public final Integer minSizeKb;
    public final Integer maxSizeKb;
    public final String pushedAfter;
    public final Integer minCommits;

    public final int targetRepos;
    public final String createdBefore;

    public final boolean appendOutput;
    public final String outputDir;
    public final String tokenFile;
    public final int threads;             // parallel clone/parse workers

    private Config(Properties p, Path baseDir)
    {
        this.runMode       = str(p, "run.mode", "GITHUB_SEARCH");
        this.localInput    = str(p, "local.input", "");
        this.singleRepoUrl = str(p, "single.repo.url", "");

        this.language   = strOrNull(p, "search.language", "java");
        this.minStars   = intOrNull(p, "search.minStars", "10");
        this.minForks   = intOrNull(p, "search.minForks", "10");
        this.minSizeKb  = intOrNull(p, "search.minSizeKb", "");
        this.maxSizeKb  = intOrNull(p, "search.maxSizeKb", "");
        this.pushedAfter = strOrNull(p, "search.pushedAfter", "2026-01-01");
        this.minCommits = intOrNull(p, "search.minCommits", "");

        this.targetRepos   = Integer.parseInt(str(p, "search.targetRepos", "5000"));
        this.createdBefore = str(p, "search.createdBefore", "2026-01-01");

        this.appendOutput = Boolean.parseBoolean(str(p, "output.append", "false"));
        // Resolve output/token paths against the module dir so they land in the
        // right place regardless of the launch working directory.
        this.outputDir    = resolve(baseDir, str(p, "output.dir", "..\\analysis\\data_tables"));
        this.tokenFile    = resolve(baseDir, str(p, "token.file", ".token"));
        this.threads      = Math.max(1, Integer.parseInt(str(p, "threads", "4")));
    }

    public static Config load(String path) throws IOException
    {
        Properties p = new Properties();

        Path file;
        if (path != null && !path.isBlank())
            file = Path.of(path);
        else
            file = locateConfig();

        Path baseDir;
        if (file != null && Files.exists(file))
        {
            try (InputStream in = Files.newInputStream(file))
            {
                p.load(in);
            }
            baseDir = file.toAbsolutePath().getParent();
            System.out.println("Loaded configuration from " + file.toAbsolutePath());
        }
        else
        {
            baseDir = moduleDir();
            System.out.println("No config file found - using built-in defaults"
                    + " (output base: " + baseDir + ").");
        }

        return new Config(p, baseDir);
    }

    /** Looks for config.properties first in the working dir, then beside the module. */
    private static Path locateConfig()
    {
        Path cwd = Path.of("config.properties");
        if (Files.exists(cwd))
            return cwd;

        Path beside = moduleDir().resolve("config.properties");
        if (Files.exists(beside))
            return beside;

        return cwd; // non-existent; triggers the defaults branch
    }

    /**
     * The module directory (the folder containing pom.xml), discovered from the
     * location of the compiled classes/jar rather than the working directory.
     */
    private static Path moduleDir()
    {
        try
        {
            Path codeLocation = Paths.get(Config.class.getProtectionDomain()
                    .getCodeSource().getLocation().toURI());
            Path dir = Files.isDirectory(codeLocation) ? codeLocation : codeLocation.getParent();
            for (Path p = dir; p != null; p = p.getParent())
            {
                if (Files.exists(p.resolve("pom.xml")))
                    return p;
            }
            return dir != null ? dir : Path.of("").toAbsolutePath();
        }
        catch (URISyntaxException | RuntimeException e)
        {
            return Path.of("").toAbsolutePath();
        }
    }

    private static String resolve(Path baseDir, String value)
    {
        if (value == null || value.isEmpty())
            return value;
        Path resolved = baseDir.resolve(value).normalize();
        return resolved.toString();
    }

    private static String str(Properties p, String key, String def)
    {
        String v = p.getProperty(key);
        return (v == null) ? def : v.trim();
    }

    private static String strOrNull(Properties p, String key, String def)
    {
        String v = str(p, key, def);
        return v.isEmpty() ? null : v;
    }

    private static Integer intOrNull(Properties p, String key, String def)
    {
        String v = str(p, key, def);
        return v.isEmpty() ? null : Integer.valueOf(v);
    }
}
