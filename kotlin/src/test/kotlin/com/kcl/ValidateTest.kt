package com.kcl;

import com.kcl.api.API
import com.kcl.api.validateCodeArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class ValidateTest {
    @Test
    fun testValidateCodeApi() {
        val args = validateCodeArgs { 
            code =  "schema Person:\n" + "    name: str\n" + "    age: int\n" + "    check:\n" + "        0 < age < 120\n"
            data = "{\"name\": \"Alice\", \"age\": 10}"
        }
        val apiInstance = API();
        val result = apiInstance.validateCode(args);

        assertEquals(true, result.getSuccess());
        assertEquals("", result.getErrMessage());
    }
}
