test_person = lambda {
    a = Person{}
    assert a.name == 'kcl'
}
test_person_age = lambda {
    a = Person{}
    assert a.age == 1
}
test_person_ok = lambda {
    a = Person{}
    assert a.name == "kcl"
    assert a.age == 1
}
