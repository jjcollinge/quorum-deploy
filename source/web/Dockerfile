FROM microsoft/aspnetcore-build:1.1
ARG source=.
WORKDIR /app
EXPOSE 80
COPY $source .
RUN dotnet restore
ENTRYPOINT ["dotnet", "run"]