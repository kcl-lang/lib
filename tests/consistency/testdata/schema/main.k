schema Person:
    name: str
    age?: int = 18

alice = Person {name = "Alice"}
nums = [i * 2 for i in [1, 2, 3]]
total = sum(nums)
