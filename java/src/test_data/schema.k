schema AppConfig:
    replicas: int = 1
    int_lit_ty_attr: 1 = 1

a = 1

app: AppConfig {
    replicas: a + 1
}
