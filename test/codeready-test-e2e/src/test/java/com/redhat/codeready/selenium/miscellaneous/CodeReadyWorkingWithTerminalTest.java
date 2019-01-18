package com.redhat.codeready.selenium.miscellaneous;

import org.eclipse.che.selenium.miscellaneous.WorkingWithTerminalTest;
import org.testng.annotations.Test;

/** @author Aleksandr Shmaraev */
public class CodeReadyWorkingWithTerminalTest extends WorkingWithTerminalTest {

  @Override
  @Test(enabled = false)
  public void shouldScrollAndAppearMCDialogs() {}

  @Override
  @Test(enabled = false)
  public void shouldResizeTerminal() {}

  @Override
  @Test(enabled = false)
  public void shouldNavigateToMC() {}

  @Override
  @Test(enabled = false)
  public void shouldTurnToNormalModeFromAlternativeScreenModeAndOtherwise() {}

  @Override
  @Test(enabled = false)
  public void shouldOpenMCHelpDialogAndUserMenuDialog() {}

  @Override
  @Test(enabled = false)
  public void shouldViewFolderIntoMC() {}

  @Override
  @Test(enabled = false)
  public void shouldEditFileIntoMCEdit() {}

  @Override
  protected String[] getExpectedContent() {
    return new String[] {"che", "a.txt"};
  }
}
