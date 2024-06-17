
schema Pot: 
    name: str
    number: int

schema Test:
    aType?: str
    pots?: [Pot]


tests = Test {
    pots: [
        Pot {
            name: "http"
            number: 90
        }
    ]
}