Docker usage

Build image:

```powershell
docker build -t dogonomics:latest .
```

Run with env file (make sure .env contains your API keys):

```powershell
docker run --env-file .env -p 8080:8080 dogonomics:latest
```

Or with docker-compose:

```powershell
docker-compose up --build
```

Swagger UI will be available at http://localhost:8080/swagger/index.html after generating docs with `swag init` and adding the generated `docs` package to the build.
