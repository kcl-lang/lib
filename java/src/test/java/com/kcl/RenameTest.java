package com.kcl;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.RenameCode_Args;
import com.kcl.api.Spec.RenameCode_Result;
import com.kcl.api.Spec.Rename_Args;
import com.kcl.api.Spec.Rename_Result;

public class RenameTest {
    @Test
    public void testRenameCode() throws Exception {
        API api = new API();
        RenameCode_Args args = RenameCode_Args.newBuilder().setPackageRoot("/mock/path").setSymbolPath("a")
                .putSourceCodes("/mock/path/main.k", "a = 1\nb = a").setNewName("a2").build();
        RenameCode_Result result = api.renameCode(args);
        Assert.assertEquals(result.getChangedCodesOrThrow("/mock/path/main.k"), "a2 = 1\nb = a2");
    }

    @Test
    public void testRename() throws Exception {
        String backupContent = new String(Files.readAllBytes(Paths.get("./src/test_data/rename/main.bak")),
                StandardCharsets.UTF_8);
        Files.write(Paths.get("./src/test_data/rename/main.k"), backupContent.getBytes(StandardCharsets.UTF_8));

        Rename_Args args = Rename_Args.newBuilder().setPackageRoot("./src/test_data/rename").setSymbolPath("a")
                .addFilePaths("./src/test_data/rename/main.k").setNewName("a2").build();

        API apiInstance = new API();
        Rename_Result result = apiInstance.rename(args);

        Assert.assertTrue(result.getChangedFiles(0), result.getChangedFiles(0).contains("main.k"));
    }
}
