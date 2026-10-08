schema Config:
    """A config with a default and a check."""

    name: str = "demo"
    replicas: int = 2

    check:
        replicas > 0, "replicas must be positive"

app = Config {name = "svc", replicas = 3}
