schema Person:
    name: str = "kcl"
    age: int = 1

    check:
        0 <= age <= 120, "age must be in [0, 120]"

hello = Person {
    name = "hello kcl"
    age = 102
}
