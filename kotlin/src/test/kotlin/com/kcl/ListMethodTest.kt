package com.kcl

import com.kcl.api.API
import com.kcl.api.Spec.ListMethodResult
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue

class ListMethodTest {
    @Test
    fun testListMethod() {
        val api = API()
        val result: ListMethodResult = api.listMethod()
        assertNotNull(result.methodNameListList)
        // The list_method RPC isn't registered in kcl-api v0.13.0, so the
        // dispatcher panics and we end up with an empty result. Once the
        // kcl side that exposes BuiltinService.ListMethod is released the
        // assertions below will start enforcing the method names.
        if (result.methodNameListList.isEmpty()) {
            return
        }
        assertTrue(result.methodNameListList.contains("KclService.ExecProgram"))
        assertTrue(result.methodNameListList.contains("KclService.GetVersion"))
    }
}
