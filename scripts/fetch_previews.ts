// Usage: deno task previews [--force]

import { fileURLToPath } from "node:url";

const ASSETS = new URL("../web/priv/assets/work/", import.meta.url);
const WEB = new URL("../web/", import.meta.url);
const REQUEST_TIMEOUT_MILLISECONDS = 60_000;
const FORMATS = new Map([
  ["png", { type: "png", contentType: "image/png" }],
  ["jpg", { type: "jpeg", contentType: "image/jpeg" }],
  ["jpeg", { type: "jpeg", contentType: "image/jpeg" }],
]);

type Project = {
  name: string;
  url: string;
  kind: "image" | "video";
  file: string;
};

function projects(value: unknown): Project[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("the Gleam export must contain a non-empty project array");
  }

  const files = new Set<string>();

  return value.map((entry: unknown) => {
    if (
      typeof entry !== "object" || entry === null ||
      !("name" in entry) || typeof entry.name !== "string" || !entry.name ||
      !("url" in entry) || typeof entry.url !== "string" ||
      !("source" in entry) || typeof entry.source !== "string" ||
      !("kind" in entry) || (entry.kind !== "image" && entry.kind !== "video")
    ) {
      throw new Error("invalid project in the Gleam export");
    }

    const url = new URL(entry.url);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      throw new Error(`unsupported project URL for ${entry.name}`);
    }

    const file = entry.source.slice("/work/".length);
    if (
      !entry.source.startsWith("/work/") ||
      !/^[a-z0-9][a-z0-9._-]*$/i.test(file) || files.has(file)
    ) {
      throw new Error(`invalid or duplicate preview path: ${entry.source}`);
    }

    files.add(file);

    return { name: entry.name, url: entry.url, kind: entry.kind, file };
  });
}

async function loadProjects(): Promise<Project[]> {
  const { success, stdout } = await new Deno.Command("gleam", {
    cwd: WEB,
    args: ["run", "--no-print-progress", "-m", "web/preview"],
    stdout: "piped",
    stderr: "inherit",
  }).output();

  if (!success) throw new Error("could not export the Gleam project manifest");

  return projects(JSON.parse(new TextDecoder().decode(stdout)));
}

async function exists(file: URL): Promise<boolean> {
  try {
    const info = await Deno.stat(file);
    if (!info.isFile) {
      throw new Error(`preview is not a file: ${file.pathname}`);
    }

    return true;
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return false;

    throw error;
  }
}

async function shoot(
  project: Project,
  format: { type: string; contentType: string },
): Promise<Uint8Array> {
  const endpoint = new URL("https://api.microlink.io/");
  endpoint.searchParams.set("url", project.url);
  endpoint.searchParams.set("screenshot", "true");
  endpoint.searchParams.set("screenshot.type", format.type);
  endpoint.searchParams.set("meta", "false");
  endpoint.searchParams.set("embed", "screenshot.url");
  endpoint.searchParams.set("colorScheme", "dark");
  endpoint.searchParams.set("viewport.width", "1280");
  endpoint.searchParams.set("viewport.height", "800");

  const response = await fetch(endpoint, {
    headers: { accept: format.contentType },
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MILLISECONDS),
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(
      `microlink answered ${response.status} for ${project.name}`,
    );
  }

  const contentType = response.headers.get("content-type")?.split(";")[0]
    .trim();
  if (contentType !== format.contentType) {
    await response.body?.cancel();
    throw new Error(
      `expected ${format.contentType}, got ${contentType} for ${project.name}`,
    );
  }

  const image = new Uint8Array(await response.arrayBuffer());
  if (image.length === 0) {
    throw new Error(`empty screenshot for ${project.name}`);
  }

  return image;
}

async function save(file: URL, image: Uint8Array): Promise<void> {
  const temporary = await Deno.makeTempFile({
    dir: fileURLToPath(ASSETS),
    prefix: ".preview-",
  });

  try {
    await Deno.writeFile(temporary, image);
    await Deno.rename(temporary, file);
  } finally {
    await Deno.remove(temporary).catch((error: unknown) => {
      if (!(error instanceof Deno.errors.NotFound)) {
        console.warn(`could not clean up ${temporary}: ${error}`);
      }
    });
  }
}

async function main(): Promise<void> {
  const force = Deno.args.includes("--force");
  const found = await loadProjects();

  await Deno.mkdir(ASSETS, { recursive: true });

  const results = await Promise.allSettled(found.map(async (project) => {
    const extension = project.file.split(".").pop()?.toLowerCase() ?? "";
    const format = FORMATS.get(extension);

    if (project.kind === "video" || !format) {
      console.log(
        `skipping ${project.name}, ${project.file} is not a screenshot format`,
      );
      return;
    }

    const file = new URL(project.file, ASSETS);
    if (!force && await exists(file)) {
      console.log(`skipping ${project.name}, ${project.file} already exists`);
      return;
    }

    console.log(`shooting ${project.name} from ${project.url}`);
    await save(file, await shoot(project, format));
    console.log(`wrote ${file.pathname}`);
  }));

  const failures = results.filter((result) => result.status === "rejected");
  for (const failure of failures) console.error(String(failure.reason));

  if (failures.length > 0) {
    throw new Error(`${failures.length} preview(s) failed`);
  }
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(String(error));
    Deno.exit(1);
  }
}
