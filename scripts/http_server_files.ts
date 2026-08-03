import { serveDir, serveFile } from "jsr:@std/http/file-server";

Deno.serve((req: Request) => {
    const pathname = new URL(req.url).pathname;

    // if (pathname.startsWith("/static")) {
    return serveDir(req, {
        fsRoot: "./web/dist",
    });
    // }

    // return new Response("404: Not Found", {
    // status: 404,
    // });
}); 