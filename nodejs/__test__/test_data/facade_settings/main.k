env = option("env", default="dev")
replicas = option("replicas", default=1)

app = {
    name = "demo"
    env = env
    replicas = replicas
}

empty = None
