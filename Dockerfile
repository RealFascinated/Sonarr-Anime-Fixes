# Frontend build
FROM node:20-alpine AS frontend
WORKDIR /build
COPY package.json yarn.lock ./
COPY frontend/ ./frontend/
RUN yarn install --frozen-lockfile
RUN yarn build

# Backend build
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS backend
WORKDIR /build
COPY global.json ./
COPY src/ ./src/
RUN dotnet restore src/Sonarr.sln
COPY --from=frontend /build/_output/UI ./_output/UI
WORKDIR /build/src/NzbDrone.Mono
RUN dotnet publish -c Release -f net10.0 -o /app -r linux-musl-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false
WORKDIR /build/src/NzbDrone.Console
RUN dotnet publish -c Release -f net10.0 -o /app -r linux-musl-x64 --self-contained false \
    -p:TreatWarningsAsErrors=false \
    -p:RunAnalyzersDuringBuild=false && \
    cp -r /build/_output/UI /app/UI

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
WORKDIR /app

RUN apk add --no-cache \
        sqlite-libs \
        mediainfo \
        icu-data-full \
        ca-certificates

COPY --from=backend /app .

EXPOSE 8989
VOLUME [ "/config", "/tv" ]
ENTRYPOINT [ "./Sonarr" ]
