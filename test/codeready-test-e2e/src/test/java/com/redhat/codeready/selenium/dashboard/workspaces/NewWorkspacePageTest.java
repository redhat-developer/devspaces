/*
* Copyright (c) 2019 Red Hat, Inc.

* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v2.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-2.0
*
* Contributors:
*   Red Hat, Inc. - initial API and implementation
*/
package com.redhat.codeready.selenium.dashboard.workspaces;

import static java.util.Arrays.asList;
import static org.eclipse.che.commons.lang.NameGenerator.generate;
import static org.eclipse.che.selenium.pageobject.dashboard.NewWorkspace.Stack.JAVA;
import static org.openqa.selenium.Keys.ARROW_DOWN;
import static org.openqa.selenium.Keys.ARROW_UP;
import static org.openqa.selenium.Keys.ESCAPE;
import static org.testng.Assert.assertEquals;

import com.google.inject.Inject;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace;
import com.redhat.codeready.selenium.pageobject.dashboard.CodereadyNewWorkspace.CodereadyStacks;
import java.util.List;
import org.eclipse.che.selenium.core.webdriver.SeleniumWebDriverHelper;
import org.eclipse.che.selenium.pageobject.dashboard.Dashboard;
import org.eclipse.che.selenium.pageobject.dashboard.workspaces.Workspaces;
import org.openqa.selenium.Keys;
import org.testng.annotations.BeforeClass;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;

/** @author Ihor Okhrimenko */
public class NewWorkspacePageTest {
  private static final String EXPECTED_WORKSPACE_NAME_PREFIX = "wksp-";
  private static final String MACHINE_NAME = "dev-machine";
  private static final double MAX_RAM_VALUE = 100.0;
  private static final double MIN_RAM_VALUE = 0.1;
  private static final double RAM_CHANGE_STEP = 0.1;
  private static final String NAME_WITH_ONE_HUNDRED_SYMBOLS = generate("wksp-", 95);
  private static final List<String> NOT_VALID_NAMES =
      asList("wksp-", "-wksp", "wk sp", "wk_sp", "wksp@", "wksp$", "wksp&", "wksp*");
  private static final String LETTER_FOR_SEARCHING = "m";
  private static final String MAKE_SUGGESTION_TITLE = "MAKE";
  private static final String MAVEN_SUGGESTION_TITLE = "MAVEN";

  private static List<CodereadyNewWorkspace.CodereadyStacks> EXPECTED_CODEREADY_QUICK_START_STACKS =
      asList(
          CodereadyStacks.JAVA_DEFAULT,
          CodereadyStacks.JBOSS_EAP,
          CodereadyStacks.FUSE,
          CodereadyStacks.SPRING_BOOT,
          CodereadyStacks.VERTX,
          CodereadyStacks.DOT_NET,
          CodereadyStacks.CPP,
          CodereadyStacks.GO,
          CodereadyStacks.NODE8,
          CodereadyStacks.NODE10,
          CodereadyStacks.PHP,
          CodereadyStacks.PYTHON,
          CodereadyStacks.THORNTAIL);

  private static final List<CodereadyNewWorkspace.CodereadyStacks>
      EXPECTED_CODEREADY_QUICK_START_STACKS_REVERSE_ORDER =
          asList(
              CodereadyStacks.VERTX,
              CodereadyStacks.SPRING_BOOT,
              CodereadyStacks.FUSE,
              CodereadyStacks.JBOSS_EAP,
              CodereadyStacks.JAVA_DEFAULT,
              CodereadyStacks.THORNTAIL,
              CodereadyStacks.PYTHON,
              CodereadyStacks.PHP,
              CodereadyStacks.NODE10,
              CodereadyStacks.NODE8,
              CodereadyStacks.GO,
              CodereadyStacks.CPP,
              CodereadyStacks.DOT_NET);

  private static List<CodereadyNewWorkspace.CodereadyStacks>
      EXPECTED_CODEREADY_SINGLE_MACHINE_STACKS =
          asList(
              CodereadyStacks.JAVA_DEFAULT,
              CodereadyStacks.JBOSS_EAP,
              CodereadyStacks.FUSE,
              CodereadyStacks.SPRING_BOOT,
              CodereadyStacks.VERTX,
              CodereadyStacks.DOT_NET,
              CodereadyStacks.CPP,
              CodereadyStacks.GO,
              CodereadyStacks.NODE8,
              CodereadyStacks.NODE10,
              CodereadyStacks.PHP,
              CodereadyStacks.PYTHON,
              CodereadyStacks.THORNTAIL);

  private static final List<CodereadyNewWorkspace.CodereadyStacks> EXPECTED_CODEREADY_JAVA_STACKS =
      asList(
          CodereadyStacks.THORNTAIL,
          CodereadyStacks.SPRING_BOOT,
          CodereadyStacks.JBOSS_EAP,
          CodereadyStacks.JAVA_DEFAULT);

  private static final List<String> EXPECTED_CODEREADY_FILTERS_SUGGESTIONS =
      asList(MAVEN_SUGGESTION_TITLE);

  private static final List<String> VALID_NAMES =
      asList("Wk-sp", "Wk-sp1", "9wk-sp", "5wk-sp0", "Wk19sp", "Wksp-01");

  @Inject private Dashboard dashboard;
  @Inject private Workspaces workspaces;
  @Inject private CodereadyNewWorkspace newWorkspace;
  @Inject private SeleniumWebDriverHelper seleniumWebDriverHelper;

  @BeforeClass
  public void setup() {
    dashboard.open();
  }

  @BeforeMethod
  public void prepareTestWorkspace() {
    dashboard.waitDashboardToolbarTitle();
    dashboard.selectWorkspacesItemOnDashboard();
    workspaces.waitToolbarTitleName();
    workspaces.clickOnAddWorkspaceBtn();
    newWorkspace.waitPageLoad();
  }

  @Test
  public void checkNameField() {
    newWorkspace.waitPageLoad();
    assertEquals(
        newWorkspace.getWorkspaceNameValue().substring(0, 5), EXPECTED_WORKSPACE_NAME_PREFIX);

    // empty name field
    newWorkspace.typeWorkspaceName("");
    newWorkspace.waitErrorMessage("A name is required.");
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    // too short name
    newWorkspace.typeWorkspaceName("wk");
    newWorkspace.waitErrorMessage("The name has to be more than 3 characters long.");
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    // min valid name
    newWorkspace.typeWorkspaceName("wks");
    newWorkspace.waitErrorMessageDisappearance();
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    // max valid name
    newWorkspace.typeWorkspaceName(NAME_WITH_ONE_HUNDRED_SYMBOLS);
    newWorkspace.waitErrorMessageDisappearance();
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    // too long name
    newWorkspace.typeWorkspaceName(NAME_WITH_ONE_HUNDRED_SYMBOLS + "p");
    newWorkspace.waitErrorMessage("The name has to be less than 100 characters long.");
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    // max valid name after too long name
    newWorkspace.typeWorkspaceName(NAME_WITH_ONE_HUNDRED_SYMBOLS);
    newWorkspace.waitErrorMessageDisappearance();
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    checkNotValidNames();

    checkValidNames();
  }

  @Test
  public void checkCodereadyStackButtons() {
    checkStackButtons(
        EXPECTED_CODEREADY_QUICK_START_STACKS,
        EXPECTED_CODEREADY_SINGLE_MACHINE_STACKS,
        EXPECTED_CODEREADY_QUICK_START_STACKS_REVERSE_ORDER);
  }

  @Test
  public void checkCodereadyFiltersButton() {
    checkFiltersButton(
        EXPECTED_CODEREADY_FILTERS_SUGGESTIONS, EXPECTED_CODEREADY_QUICK_START_STACKS);
  }

  @Test
  public void checkAddStackButton() {
    newWorkspace.waitPageLoad();

    // close form by "ESCAPE" button
    newWorkspace.clickOnAddStackButton();
    newWorkspace.waitCreateStackDialog();
    seleniumWebDriverHelper.sendKeys(ESCAPE.toString());
    newWorkspace.waitCreateStackDialogClosing();

    // close form by clicking on outside of form bounds
    newWorkspace.clickOnAddStackButton();
    newWorkspace.waitCreateStackDialog();
    newWorkspace.clickOnTitlePlaceCoordinate();
    newWorkspace.waitCreateStackDialogClosing();

    // close form by "Close" button
    newWorkspace.clickOnAddStackButton();
    newWorkspace.waitCreateStackDialog();
    newWorkspace.closeCreateStackDialogByCloseButton();
    newWorkspace.waitCreateStackDialogClosing();

    // close form by "Cancel" button
    newWorkspace.clickOnAddStackButton();
    newWorkspace.waitCreateStackDialog();
    newWorkspace.clickOnNoButtonInCreateStackDialog();
    newWorkspace.waitCreateStackDialogClosing();
  }

  @Test
  public void checkCodereadySearchField() {
    checkSearchField(EXPECTED_CODEREADY_JAVA_STACKS, EXPECTED_CODEREADY_QUICK_START_STACKS);
  }

  @Test
  public void checkRamSelection() {
    newWorkspace.waitPageLoad();

    // empty RAM
    newWorkspace.selectStack(JAVA);
    newWorkspace.waitStackSelected(JAVA);
    newWorkspace.waitRamValue(MACHINE_NAME, 2.0);
    newWorkspace.typeToRamField("");
    newWorkspace.waitRedRamFieldBorders();
    newWorkspace.waitTopCreateWorkspaceButtonDisabled();
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    // max valid value
    newWorkspace.typeToRamField(Double.toString(MAX_RAM_VALUE));
    newWorkspace.waitRedRamFieldBordersDisappearance();
    newWorkspace.waitTopCreateWorkspaceButtonEnabled();
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    // increment and decrement buttons with max valid value
    newWorkspace.clickOnIncrementMemoryButton(MACHINE_NAME);
    newWorkspace.waitRamValue(MACHINE_NAME, MAX_RAM_VALUE);

    newWorkspace.clickOnDecrementMemoryButton(MACHINE_NAME);
    newWorkspace.waitRamValue(MACHINE_NAME, MAX_RAM_VALUE - RAM_CHANGE_STEP);

    // min valid value
    newWorkspace.typeToRamField("");
    newWorkspace.waitRedRamFieldBorders();
    newWorkspace.waitTopCreateWorkspaceButtonDisabled();
    newWorkspace.waitBottomCreateWorkspaceButtonDisabled();

    newWorkspace.typeToRamField(Double.toString(MIN_RAM_VALUE));
    newWorkspace.waitRedRamFieldBordersDisappearance();
    newWorkspace.waitTopCreateWorkspaceButtonEnabled();
    newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

    // increment and decrement buttons with min valid value
    newWorkspace.clickOnDecrementMemoryButton(MACHINE_NAME);
    newWorkspace.waitRamValue(MACHINE_NAME, MIN_RAM_VALUE);
    newWorkspace.clickOnIncrementMemoryButton(MACHINE_NAME);
    newWorkspace.waitRamValue(MACHINE_NAME, MIN_RAM_VALUE + RAM_CHANGE_STEP);

    // increment and decrement by click and hold
    newWorkspace.clickAndHoldIncrementMemoryButton(MACHINE_NAME, 3);
    newWorkspace.waitRamValueInSpecifiedRange(MACHINE_NAME, 3, MAX_RAM_VALUE);

    double currentRamAmount = newWorkspace.getRAM(MACHINE_NAME);
    newWorkspace.clickAndHoldDecrementMemoryButton(MACHINE_NAME, 3);
    newWorkspace.waitRamValueInSpecifiedRange(MACHINE_NAME, MIN_RAM_VALUE, currentRamAmount - 2);
  }

  private void checkStackButtons(
      List<CodereadyNewWorkspace.CodereadyStacks> expectedQuickStartStacks,
      List<CodereadyNewWorkspace.CodereadyStacks> expectedSingleMachineStacks,
      List<CodereadyNewWorkspace.CodereadyStacks> expectedQuickStartStacksReverseOrder) {

    newWorkspace.waitPageLoad();
    newWorkspace.waitQuickStartButton();
    newWorkspace.waitCodereadyStacks(expectedQuickStartStacks);
    assertEquals(newWorkspace.getCodereadyStacksCount(), expectedQuickStartStacks.size());

    // single machine stacks
    newWorkspace.clickOnSingleMachineButton();
    newWorkspace.waitCodereadyStacks(expectedSingleMachineStacks);
    assertEquals(newWorkspace.getCodereadyStacksCount(), expectedSingleMachineStacks.size());

    // check that only expected stacks are displayed and no duplicates are presented and also checks
    // "All" stacks
    newWorkspace.clickOnAllButton();
    newWorkspace.waitCodereadyStacks(expectedSingleMachineStacks);
    assertEquals(newWorkspace.getCodereadyStacksCount(), expectedSingleMachineStacks.size());

    // quick start stacks
    newWorkspace.clickOnQuickStartButton();
    newWorkspace.waitCodereadyStacksOrder(expectedQuickStartStacks);

    newWorkspace.clickNameButton();
    newWorkspace.waitCodereadyStacksOrder(expectedQuickStartStacksReverseOrder);

    newWorkspace.clickNameButton();
    newWorkspace.waitCodereadyStacksOrder(expectedQuickStartStacks);
  }

  private void checkFiltersButton(
      List<String> expectedSuggestions,
      List<CodereadyNewWorkspace.CodereadyStacks> expectedQuickStartStacks) {
    newWorkspace.waitPageLoad();

    // close by "Escape" button
    newWorkspace.clickOnFiltersButton();
    newWorkspace.waitFiltersFormOpened();
    seleniumWebDriverHelper.sendKeys(ESCAPE.toString());
    newWorkspace.waitFiltersFormClosed();

    // close by clicking on the outside of the "Filters" form
    newWorkspace.clickOnFiltersButton();
    newWorkspace.waitFiltersFormOpened();
    newWorkspace.clickOnTitlePlaceCoordinate();
    newWorkspace.waitFiltersFormClosed();

    // check suggestion list
    newWorkspace.clickOnFiltersButton();
    newWorkspace.waitFiltersFormOpened();
    newWorkspace.typeToFiltersInput(LETTER_FOR_SEARCHING);
    newWorkspace.waitFiltersSuggestionsNames(expectedSuggestions);

    assertEquals(
        newWorkspace.getSelectedFiltersSuggestionName(),
        newWorkspace.getFiltersSuggestionsNames().get(0));

    // check navigation by keyboard arrows between suggested tags
    seleniumWebDriverHelper.sendKeys(ARROW_DOWN.toString());
    newWorkspace.waitSelectedFiltersSuggestion(MAKE_SUGGESTION_TITLE);

    seleniumWebDriverHelper.sendKeys(ARROW_UP.toString());
    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);

    // interaction with suggested tads by mouse clicking
    newWorkspace.clickOnFiltersSuggestions(MAVEN_SUGGESTION_TITLE);
    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);

    newWorkspace.clickOnFiltersSuggestions(MAKE_SUGGESTION_TITLE);
    newWorkspace.waitSelectedFiltersSuggestion(MAKE_SUGGESTION_TITLE);

    newWorkspace.doubleClickOnFiltersSuggestion(MAKE_SUGGESTION_TITLE);
    newWorkspace.waitFiltersInputTags(asList(MAKE_SUGGESTION_TITLE));

    newWorkspace.deleteLastTagFromInputTagsField();
    newWorkspace.waitFiltersInputIsEmpty();

    // delete tags from input
    newWorkspace.typeToFiltersInput(LETTER_FOR_SEARCHING);
    newWorkspace.waitFiltersSuggestionsNames(expectedSuggestions);

    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);
    newWorkspace.doubleClickOnFiltersSuggestion(MAVEN_SUGGESTION_TITLE);
    newWorkspace.waitFiltersInputTags(asList(MAVEN_SUGGESTION_TITLE));
    newWorkspace.deleteTagByRemoveButton(MAVEN_SUGGESTION_TITLE);
    newWorkspace.waitFiltersInputIsEmpty();

    newWorkspace.typeToFiltersInput(LETTER_FOR_SEARCHING);
    newWorkspace.waitFiltersSuggestionsNames(expectedSuggestions);
    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);
    newWorkspace.chooseFilterSuggestionByPlusButton(MAKE_SUGGESTION_TITLE);
    newWorkspace.waitFiltersInputTags(asList(MAKE_SUGGESTION_TITLE));
    newWorkspace.clickOnInputFieldTag(MAKE_SUGGESTION_TITLE);
    seleniumWebDriverHelper.sendKeys(Keys.DELETE.toString());
    newWorkspace.waitFiltersInputIsEmpty();

    newWorkspace.typeToFiltersInput(LETTER_FOR_SEARCHING);
    newWorkspace.waitFiltersSuggestionsNames(expectedSuggestions);
    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);
    newWorkspace.chooseFilterSuggestionByPlusButton(MAVEN_SUGGESTION_TITLE);
    newWorkspace.waitFiltersInputTags(asList(MAVEN_SUGGESTION_TITLE));
    newWorkspace.clickOnInputFieldTag(MAVEN_SUGGESTION_TITLE);
    seleniumWebDriverHelper.sendKeys(Keys.DELETE.toString());
    newWorkspace.waitFiltersInputIsEmpty();
    newWorkspace.deleteLastTagFromInputTagsField();

    // navigation by "Tab" button
    newWorkspace.typeToFiltersInput(LETTER_FOR_SEARCHING);
    newWorkspace.waitSelectedFiltersSuggestion(MAVEN_SUGGESTION_TITLE);
    seleniumWebDriverHelper.sendKeys(Keys.TAB.toString());
    newWorkspace.waitSelectedFiltersSuggestion(MAKE_SUGGESTION_TITLE);
    seleniumWebDriverHelper.sendKeys(Keys.ENTER.toString());
    newWorkspace.waitFiltersInputTags(asList(MAKE_SUGGESTION_TITLE));
    newWorkspace.clickOnTitlePlaceCoordinate();
    newWorkspace.waitFiltersFormClosed();

    newWorkspace.clickOnFiltersButton();
    newWorkspace.waitFiltersFormOpened();
    newWorkspace.waitFiltersInputTags(asList(MAKE_SUGGESTION_TITLE));
    newWorkspace.deleteLastTagFromInputTagsField();
    newWorkspace.waitFiltersInputIsEmpty();
    newWorkspace.clickOnTitlePlaceCoordinate();
    newWorkspace.waitFiltersFormClosed();
    newWorkspace.waitCodereadyStacks(expectedQuickStartStacks);
  }

  private void checkSearchField(
      List<CodereadyNewWorkspace.CodereadyStacks> expectedJavaStacks,
      List<CodereadyNewWorkspace.CodereadyStacks> expectedQuickStartStacks) {
    newWorkspace.waitPageLoad();

    newWorkspace.typeToSearchInput("Java");
    newWorkspace.waitCodereadyStacks(expectedJavaStacks);

    newWorkspace.typeToSearchInput("");
    newWorkspace.waitCodereadyStacks(expectedQuickStartStacks);

    newWorkspace.typeToSearchInput("java");
    newWorkspace.waitCodereadyStacks(expectedJavaStacks);

    newWorkspace.typeToSearchInput("");
    newWorkspace.waitCodereadyStacks(expectedQuickStartStacks);

    newWorkspace.typeToSearchInput("JAVA");
    newWorkspace.waitCodereadyStacks(expectedJavaStacks);

    newWorkspace.typeToSearchInput("");
    newWorkspace.waitCodereadyStacks(expectedQuickStartStacks);
  }

  private void checkNotValidNames() {
    NOT_VALID_NAMES.forEach(
        name -> {
          newWorkspace.typeWorkspaceName("temporary");
          newWorkspace.waitErrorMessageDisappearance();
          newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

          newWorkspace.typeWorkspaceName(name);
          newWorkspace.waitErrorMessage(
              "The name should not contain special characters like space, dollar, etc. and should start and end only with digits, latin letters or underscores.");
          newWorkspace.waitBottomCreateWorkspaceButtonDisabled();
        });
  }

  private void checkValidNames() {
    VALID_NAMES.forEach(
        name -> {
          newWorkspace.typeWorkspaceName("temporary");
          newWorkspace.waitErrorMessageDisappearance();
          newWorkspace.waitBottomCreateWorkspaceButtonEnabled();

          newWorkspace.typeWorkspaceName(name);
          newWorkspace.waitErrorMessageDisappearance();
          newWorkspace.waitBottomCreateWorkspaceButtonEnabled();
        });
  }
}
