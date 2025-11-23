package com.kcl;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.RenameCodeArgs;
import com.kcl.api.Spec.RenameCodeResult;
import com.kcl.api.Spec.RenameArgs;
import com.kcl.api.Spec.RenameResult;

public class RenameTest {
    @Test
    public void testRenameCode() throws Exception {
        API api = new API();
        RenameCodeArgs args = RenameCodeArgs.newBuilder().setPackageRoot("/mock/path").setSymbolPath("a")
                .putSourceCodes("/mock/path/main.k", "a = 1\nb = a").setNewName("a2").build();
        RenameCodeResult result = api.renameCode(args);
        Assert.assertEquals(result.getChangedCodesOrThrow("/mock/path/main.k"), "a2 = 1\nb = a2");
    }

    @Test
    public void testRename() throws Exception {
        String backupContent = new String(Files.readAllBytes(Paths.get("./src/test_data/rename/main.bak")),
                StandardCharsets.UTF_8);
        Files.write(Paths.get("./src/test_data/rename/main.k"), backupContent.getBytes(StandardCharsets.UTF_8));

        RenameArgs args = RenameArgs.newBuilder().setPackageRoot("./src/test_data/rename").setSymbolPath("a")
                .addFilePaths("./src/test_data/rename/main.k").setNewName("a2").build();

        API apiInstance = new API();
        RenameResult result = apiInstance.rename(args);

        Assert.assertTrue(result.getChangedFiles(0), result.getChangedFiles(0).contains("main.k"));
    }
}
