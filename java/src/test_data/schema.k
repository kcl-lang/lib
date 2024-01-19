import pkg

schema AppConfig:
    replicas: int = 1

app: AppConfig {
    replicas: pkg.a + 1
}
