FROM node:20-alpine AS frontend
WORKDIR /build
COPY package.json yarn.lock ./
COPY frontend/ ./frontend/
RUN yarn install --frozen-lockfile && yarn build

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS backend
WORKDIR /build
COPY global.json ./
COPY src/ ./src/
RUN dotnet restore src/Sonarr.sln
COPY --from=frontend /build/_output/UI ./_output/UI
WORKDIR /build/src/NzbDrone.Mono
RUN dotnet publish -c Release -f net10.0 -o /app -r linux-musl-x64 --self-contained false \
  -p:TreatWarningsAsErrors=false -p:RunAnalyzersDuringBuild=false
WORKDIR /build/src/NzbDrone.Console
RUN dotnet publish -c Release -f net10.0 -o /app -r linux-musl-x64 --self-contained false \
  -p:TreatWarningsAsErrors=false -p:RunAnalyzersDuringBuild=false && cp -r /build/_output/UI /app/UI

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app
RUN apk add --no-cache ca-certificates icu-data-full mediainfo sqlite-libs
COPY --from=backend /app .
EXPOSE 8989
VOLUME ["/config", "/tv"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8989/api/v3/system/status || exit 1
ENTRYPOINT ["./Sonarr"]
