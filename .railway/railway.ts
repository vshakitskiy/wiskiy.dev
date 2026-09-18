import { defineRailway, github, preserve, project, service } from "railway/iac";

const repository = "vshakitskiy/wiskiy.dev";

export default defineRailway(() => {
  const api = service("api", {
    source: github(repository, { branch: "mistress" }),
    build: {
      builder: "DOCKERFILE",
      dockerfilePath: "api/Dockerfile",
      watchPatterns: ["api/**"],
    },
    deploy: {
      healthcheckPath: "/health",
      restartPolicyType: "ON_FAILURE",
    },
    env: {
      PORT: "8080",
      GITHUB_LOGIN: "vshakitskiy",
      GITHUB_TOKEN: preserve(),
    },
  });

  const web = service("web", {
    source: github(repository, { branch: "mistress" }),
    build: {
      builder: "DOCKERFILE",
      dockerfilePath: "web/Dockerfile",
      watchPatterns: ["web/**", "Makefile"],
    },
    deploy: {
      healthcheckPath: "/",
      restartPolicyType: "ON_FAILURE",
    },
    env: {
      PORT: "8080",
      API_HOST: api.env.RAILWAY_PRIVATE_DOMAIN,
      API_PORT: api.env.PORT,
    },
  });

  return project("wiskiy.dev", { resources: [api, web] });
});
