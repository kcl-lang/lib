
schema AppConfig:
    replicas: int = 1

app: AppConfig {
    replicas = 2
}
