## 2.5.9

- `UIRootComponent`:
  - Constructor:
    - register at `_rootComponentInstances`, using `WeakReference`.
  - Added `getInstances`.

- `UIComponent`:
  - `_getUIComponentByContent`, `_getUIComponentByChild`:
    - Search first through `UIRoot.getInstance()` and also through `UIRootComponent.getInstances()`.

## 2.5.8

- sdk: '>=3.4.0 <4.0.0'

- intl_messages: ^2.3.1
- statistics: ^1.1.1
- extended_type: ^2.1.0

## 2.5.7

- `UIElementExtension`:
  - `setValue`: handle `SelectElement`.

- dom_tools: ^2.3.1
- archive: ^3.6.1
- test: ^1.25.8
- test_api: ^0.7.3
- test_core: ^0.6.5

## 2.5.6

- `ElementExtension`:
  - `resolveElementValue`: optimize for `InputElement`.
  - Added `resolveInputElementValue`.

- `UIComponent`:
  - Added `selectElementsValues`

- dom_builder: ^2.2.5
- test: ^1.25.7
- test_api: ^0.7.2
- test_core: ^0.6.4

## 2.5.5

- New `UIRootComponent`:
  - Implemented by `UIRoot` and `UIDialogBase`

- `UIComponent`:
  - Extends `UIRootComponent`.
  - Added getter `uiRootComponent`.
  - Added `renderingUIComponent`: returns the current rendering component in the stack,
  - Added `parentRenderingUIComponent`: can resolve asynchronous parent renderer.
  - `_construct`: improved parent `UIComponent` resolution.
  - `resolveTextIntl`: improve resolution of `uiRoot` and call to `intlMessageResolver`.

- `UIDialogBase` extends `UIRootComponent`:
  - `getRenderedUIComponentById`, `getRenderedUIComponents`: fix resolution of child `UIComponent`s. 

- `UIInputTable`:
  - Added field `scrollToInvalidElement`.
- `InputConfig`:
  - Added field `labelVerticalAlign`

- dom_builder: ^2.2.3
- archive: ^3.5.1
- args: ^2.5.0
- test: ^1.25.5
- test_core: ^0.6.2

## 2.5.4

- New `UIComponentDOMContext`.

- `UIDOMGenerator`:
  - Optimize `attachFutureElement` using `UIComponentDOMContext.uiComponent` to resolve `parentComponent`. 

- mercury_client: ^2.2.2
- test: ^1.25.3
- test_api: ^0.7.1
- test_core: ^0.6.1
- build_web_compilers: ^4.0.10
- build_runner: ^2.4.9

## 2.5.3

- `testUI`:
  - Fix `tearDownAll`, declared before `setUpAll` (before call to `spawnHybridUri`). 

- `SpawnHybrid`: added field `finalizer`.

## 2.5.2

- `UIElementExtension`:
  - Fix `setValue` for `checkbox`.

## 2.5.1

- `bones_ui_web`:
  - `setValue`: Update handling of `CheckboxInputElement`.

## 2.5.0

- sdk: '>=3.3.0 <4.0.0'

- intl_messages: ^2.3.0
- dom_tools: ^2.3.0
- json_render: ^2.1.0
- swiss_knife: ^3.2.0
- statistics: ^1.1.0
- project_template: ^1.1.0
- intl: ^0.19.0
- test: ^1.25.2
- test_api: ^0.7.0
- test_core: ^0.6.0

- build_web_compilers: ^4.0.9
- build_runner: ^2.4.8

## 2.4.1

- `UIDialog`:
  - Added `getAllDialogs` and `removeAllDialogs`.

- mercury_client: ^2.2.1
- swiss_knife: ^3.1.6
- archive: ^3.4.10
- build_web_compilers: ^4.0.8

## 2.4.0

- New `bones_ui_web.dart`:
  - Avoid imports to `dart:html` in preparation to use of `dart:web` or other alternatives.
  - New typedef `UINode` and `UIElement`.
- Replace usage of `Element` to `UIElement` and `Node` to `UINode`.
- `UIComponent`:
  - Constructor:
    - parameter `parent` now accepts `Element` or `UIComponent`.
  - `toContentElements`: changed to named parameters.

- intl_messages: ^2.2.3
- dom_tools: ^2.2.0

## 2.3.3

- `UIComponent`:
  - Optimize: `getFields`, `parseChildElementValue` and `getFieldExtended`.
- `ElementExtension`:
  - Optimize: `resolveElementValue`

- intl_messages: ^2.2.2
- path: ^1.9.0

## 2.3.2

- `UIDialogBase`, `UIDialog`:
  - Added `onClickListenOnlyForDialogButtonClass` to constructor.

## 2.3.1

- `UITestChain`
  - Added `selectUntil`

## 2.3.0

- selectFirstWhereUntil:
  - Removed parameter `expected`.
  - Throw exception when can't select element.

- sdk: '>=3.2.0 <4.0.0'
- intl_messages: ^2.2.1
- archive: ^3.4.9

## 2.2.8

- `UITestChainNode`:
  - Added: `selectWhere`, `selectFirstWhere`, `selectWhereUntil`, `selectFirstWhereUntil`.

## 2.2.7

- statistics: ^1.0.26
- expressions: ^0.2.5+1
- archive: ^3.4.7
- test: ^1.24.9
- test_core: ^0.5.9
- build_web_compilers: ^4.0.6

## 2.2.6

- `UINavigableContent`: added `style` to constructor.
- Fix `UIMasonry`.
- Fix `$uiSVG`.
- `UINavigator`:
  - `clearDetachedNavigables`: added parameter `ignore`. 
- dom_builder: ^2.2.2

## 2.2.5

- dom_builder: ^2.2.1
- archive: ^3.4.2
- dependency_validator: ^3.2.3

## 2.2.4

- Bones_UI CLI:
  - Added options `--enable-deferred-libraries` and `--disable-deferred-libraries`.
- `BonesUITestRunner`: added field `enableDeferredLibraries`.
- Fix typos.

- archive: ^3.3.8

## 2.2.3

- `UIDialogBase`:
  - Execute the `onClick` listeners of the buttons asynchronously (to allow custom listeners to be executed 1st).  

- dom_builder: ^2.2.0

## 2.2.2

- `UIComponent`:
  - Added `selectElement` and `selectElements`: aliases to `querySelector` and `querySelectorAll`.
  - `getField`: add parameter `def`.
  - Added `getFieldAs`.
  - Added `getFieldsGroupEntriesByPrefix`, `getFieldsGroupListByPrefix`, `getFieldsGroupByPrefix`.
  - Added `getFieldsGroupKeysByPrefix`, `getFieldsGroupValuesByPrefix`.
  - Added `getFieldsGroupChecks`, `getFieldsGroupCheckedKeys`.

- Dart CI: update and optimize jobs.

- intl_messages: ^2.2.0
- statistics: ^1.0.25
- test: ^1.24.6
- test_core: ^0.5.6

## 2.2.1

- `SelectElementExtension`: added `selectedOptionsSafe`.
- `ElementExtension.resolveElementValue`:
  - Handle bug on `SelectElement.selectedOptions` calling `selectedOptionsSafe`.

- intl_messages: ^2.1.15
- resource_portable: ^3.1.0

## 2.2.0

- `UIComponent`:
  - Expose `getContentUIComponent`
  - `addTo`, `insertTo`, `setParent`: new parameter `parentUIComponent`.
  - New static function `resolveParentUIComponent`.
- `UIDOMGenerator`:
  - New `_resolveParentUIComponent`.
- `UIInputTable`:
  - `_addTableRowCell`: call `UIComponent.resolveParentUIComponent` for child elements.

- sdk: '>=3.0.0 <4.0.0'
- intl_messages: ^2.1.14
- dom_builder: ^2.1.9
- collection: ^1.17.2
- args: ^2.4.2
- logging: ^1.2.0
- test: ^1.24.4
- test_api: ^0.6.1
- test_core: ^0.5.4
- stream_channel: ^2.1.2
- stack_trace: ^1.11.1
- build_web_compilers: ^4.0.4
- build_runner: ^2.4.6
- lints: ^2.1.1

## 2.1.25

- dom_tools: ^2.1.17
- dom_builder: ^2.1.8

## 2.1.24

- `UIComponent`:
  - Added `requestRefresh`.
- `UIButton` and `UIButtonLoader`:
  - Changed `text` to `buttonContent`
  - `text` getter/setter now is an `String` alias to `buttonContent`. 
- `UICalendar`, `UIColorPicker`, `UIMasonry`, `UIMultiSelection`:
  - Call `requestRefresh` when possible
- `UIMultiSelection`:
  - Constructor: added parameter `selections` for initial selections. 
  - Added field `autoInputFontShrink`.
- intl_messages: ^2.1.6
- dom_tools: ^2.1.16

## 2.1.23

- New `UIDialogEditImage`.
- `UICapture`:
  - Added field `photoEditor` and `editCapture`.
- intl_messages: ^2.1.5
- intl: ^0.18.1

## 2.1.22

- Allow nullable `parent` in components:
  - `UIButtonCapture`, `UIInfosTable`, `UIMasonry`, `UIMenu`, `BUIManifestRender`.
- Fix `toContentElements` and `toRenderableList`:
  - Ensure that always return a casted `List<dynamic>`.
- intl_messages: ^2.1.4
- dom_tools: ^2.1.15
- yaml: ^3.1.2
- args: ^2.4.1
- test: ^1.24.2
- test_api: ^0.5.2
- test_core: ^0.5.2

## 2.1.21

- swiss_knife: ^3.1.5
- intl_messages: ^2.0.7
- dom_tools: ^2.1.14
- dom_builder: ^2.1.7
- archive: ^3.3.7
- resource_portable: ^3.0.2

## 2.1.20 

- `InputConfig`:
  - Added field `labelStyle`.
- `UIInputTable`:
  - Added field `tableClasses`, `tableStyle`.
- dom_builder: ^2.1.6

## 2.1.19

- `UIDialog`:
  - Tag `ui-dialog`:
    - added attribute `remove-on-hide`.
- dom_builder: ^2.1.5
- swiss_knife: ^3.1.4

## 2.1.18

- `InputConfig`:
  - `textare`: width: 100%
  - `select`: max-width: 100%
- dom_builder: ^2.1.4

## 2.1.17

- `Navigation`:
  - Added `encodeParameters`, `encodeRouteAndParameters` and `routeAndParameters`.

## 2.1.16

- `UIComponent`:
  - Added static getter `domContext`.
- dom_tools: ^2.1.13
- dom_builder: ^2.1.3
- archive: ^3.3.6
- args: ^2.4.0
- logging: ^1.1.1

## 2.1.15

- `BonesUITestRunner`:
  - `_processJsonReportFile`:
    - Allow suites with paths ending with `.dart`, not only `_test.dart`.
- intl_messages: ^2.0.6

## 2.1.14

- `UITestChain`:
  - Added `checkbox`.

## 2.1.13

- `UIRoot`:
  - Added field `name`. 
- `bones_ui_test_tools.dart`:
  - Added `testMultipleUI`.
  - `testUISleepUntilRoute`, `sleepUntilRoute`:
    - Added `parameters` and `partialParameters`.
  - `UITestContext`:
    - Added `setTestWindowTitle`.
  - `testUI`:
    - Now updates the `window.top.title` for each `test(...)`.
- `bones_ui_test_cli.dart`:
  - Compatibility with `testMultipleUI` and saving of `logDocument` to the log directory.
- test: ^1.23.1
- test_core: ^0.4.24

## 2.1.12

- `bones_ui_test_tools.dart`:
  - Using `Chain.capture` for better `StackTrace`.
- Added linter rules:
  - `avoid_dynamic_calls`.
  - `avoid_type_to_string`.
  - `no_runtimeType_toString`.
  - `no_adjacent_strings_in_list`.
- dom_tools: ^2.1.11
- stack_trace: ^1.11.0

## 2.1.11

- Test Tools:
  - `testUISleepUntil` and `sleepUntil`:
    - Now accepts `FutureOr<bool>` return in the `ready` function.
  - `testUISleepUntilElement`, `sleepUntilElement` and `expectElement`:
    - Added `mapper` parameter.
- `bones_ui_test`:
  - Show `done` event at the end of the tests if `--log-directory` is passed.

## 2.1.10

- `bones_ui_test_tools.dart`:
  - `UITestChain` with `Iterable` `element`:
    - Added `elementsLength` `expectElementsLength`, `elementAt`, `first`, `firstOr`
  - Moved from extension to `UITestChain`:
    - `click`, `setValue` and `selectIndex`.
  - `_mergeStackStraces`:
    - Remove some bottom lines from `stack1` (after `TestFutureExtension.thenWithStackTrace`).
- `bones_ui_test_cli.dart`:
- `_DocumentLog`:
  - Now appending to the document `<title>` the logging `id`. 

## 2.1.9

- `ElementExtension`:
  - added `dispatchChangeEvent`.
- Added `SelectElementExtension`:
  - `selectIndex`.
- `BonesUITestRunner`:
  - Fix copy of `build` directory when it's already populated.
  - Improved console logging.
- `UITestChain`:
  - Added `selectIndex`, `where`.
- `UITestChainNode`:
  - Added `elementAs`.
- Added `TestNodeExtension` (on `dart:html.Node`):
  - `simplify`.

## 2.1.8

- `UITestChain`:
  - added `logDocument`.
- `BonesUITestRunner`
  - Added `logDirectory`.

## 2.1.7

- `UIField`:
  - Added `setFieldValue`.
- `UIComponent`:
  - Added `click`.
- `UIRoot`:
  - Added `isTest`.
- `bones_ui_test_tools.dart`:
  - Added `testUI` and `UITestContext`.
  - Added `SpawnHybrid`.
  - Added `UITestChain` tools.
- dom_tools: ^2.1.10
- test: ^1.22.2
- test_api: ^0.4.18
- test_core: ^0.4.22
- stream_channel: ^2.1.1

## 2.1.6 

- `bones_ui_test` (cli):
  - Added selected tests path to the arguments passed to the `test` runner. 

## 2.1.5

- `InputConfig`:
  - Fix `getInputConfig` when field was not found.
- expressions: ^0.2.5
- mercury_client: ^2.1.8
- dom_tools: ^2.1.9
- json_object_mapper: ^2.0.1

## 2.1.4

- `UIRoot`:
  - Added `close`, `closeOperations`, `renderClosed`, `isClosed`.
- `UIComponent`:
  - `refresh`: added parameter `forceRender`.
  - `clear`: added parameters `force` and `removeFromParent`.

## 2.1.3

- swiss_knife: ^3.1.3
- intl_messages: ^2.0.5
- json_render: ^2.0.5
- intl: ^0.18.0
- resource_portable: ^3.0.1
- build_runner: ^2.3.3

## 2.1.2

- `bones_ui` CLI:
  - Command `test`:
    - Now calls `dart run bones_ui:bones_ui_test` executable to run the tests.

## 2.1.1

- `bones_ui_test_cli`:
  - Use absolute paths to resolve directories and files.

## 2.1.0

- `bones_ui` CLI:
  - Added `test` command, for Bones_UI unit tests. 
- Added libraries:
  - `bones_ui_test` to import the Bones_UI Test tools.
  - `bones_ui_test_clit` to import the Bones_UI Test CLI (used by `test` command).
- `UIComponent`
  - Added `waiteRender`, `callRenderAndWait`, `querySelector`, `querySelectorAll`.
    - These methods can be useful in unit tests. 
- `ElementExtension`:
- Fix `UINavigator` behavior when `findNavigable` can't find a `UINavigableComponent` for the route.
- intl_messages: ^2.0.4
- dom_tools: ^2.1.8
- archive: ^3.3.5
- test: ^1.22.0
- test_api: ^0.4.17
- test_core: ^0.4.21
- path: ^1.8.3

## 2.0.27

- `UIInputTable`:
  - Exposing `onChangeTriggerDelay` in the constructor.
  - Fix `onChange` based on `InteractionCompleter`: wasn't notifying to the `InputConfig.onChangeListener`.
- Added pre-defined filed validators:
  - `FieldLengthValidator`, `fieldEmailValidator`,  `fieldURLValidator`, `fieldURLDataBase64Validator`.
- Added filed normalized:
  - `fieldNormalizerTrim`.
- Added `FieldNormalizerGroup` and `FieldValidatorGroup`.
- extended_type: ^2.0.1

## 2.0.26

- `UICapture`:
  - Added `captureAspectRatio`.
- test: ^1.22.0

## 2.0.25

- `UICapture`:
  - Added `CaptureDataFormat.url`.
  - Field `_selectedFileData` is now an internal `_CapturedData` capable to handle different interchangeable data formats.
  - Added field `captureMaxWidth` and `captureMaxHeight` for maximum captured image size.
  - Added field `photoScaleMimeType` and `photoScaleQuality` for scale operations.
- `UIComponent`:
  - Optimized `configureClasses`.
  - Show error message when trying to render an `InputConfig`.
- swiss_knife: ^3.1.2
- mercury_client: ^2.1.7
- archive: ^3.3.4

## 2.0.24

- `UIDialogBase`:
  - Added `selectDialogButtons` and `isDialogButton` for better dialog button definition.
- `UIDialog`:
  - `dialogContent` now can be `null` and `renderContent` should be overwritten.

## 2.0.23

- `InputConfig`: added field `checked`.
- `UIDialog`: added parameter `id` to constructor.
- dom_builder: ^2.1.2

## 2.0.22

- `UIRoot`:
  - Expose parameter `super.clearParent`.
  - Added `readyTimeout`: allows personalization of `isReady` timeout.
- dom_tools: ^2.1.7

## 2.0.21

- `InputConfig`:
  - Added `onActionListener`: triggered when the element is clicked or ENTER is pressed.
- dom_tools: ^2.1.6
- archive: ^3.3.2
- collection: ^1.17.0
- logging: ^1.1.0
- build_web_compilers: ^3.2.7
- build_runner: ^2.3.2
- lints: ^2.0.1
- sdk: '>=2.18.0 <3.0.0'

## 2.0.20

- Improve logging.
- Integrate with package `logging`.
- logging: ^1.0.2

## 2.0.19

- `UIDialogBase`: added parameter `removeFromDomOnHide`.
- `UIComponent`: added `focusField`.
- dom_builder: ^2.1.1

## 2.0.18

- `InputConfig`:
  - `inputRender`: Added support to render `DOMElement`.
- archive: ^3.3.1
- test: ^1.21.6
- path: ^1.8.2
- build_web_compilers: ^3.2.6
- build_runner: ^2.2.1
- sdk: '>=2.17.0 <3.0.0'

## 2.0.17

- `UICapture`:
  - Added constructor parameter `selectedFileData`.
  - Added setter `selectedFileData`.
- `InputConfig`:
  - `_renderSelect`: selected element can also match the `options` key from `inputValue`.

## 2.0.16

- Renamed `findInContentFieldComponentDeep` to `findChildDeep`.
- Added `findChildrenDeep`.
- Added `getFieldElements` and `getFieldElementByValue`.

## 2.0.15

- `UIButtonLoader`:
  - Now resolves `intl` messages for `okMessage` and `errorMessage`.
- `UIComponent`:
  - Added `resolveTextIntl`.

## 2.0.14

- Added `UIComponent`s `DOMElement` helpers:
  - `$uiButton`, `$uiDialog`, `$uiSVG`.
- dom_builder: ^2.1.0
- expressions: ^0.2.4
- lints: ^2.0.0
- dependency_validator: ^3.2.2
- test: ^1.21.4

## 2.0.13

- `UIField`:
  - Added `String get fieldName`.
  - `getFieldValue` can now return types other than `String`.
- `UIDialog`:
  - Added `blockScrollTraversing`.
- New components`UICalendar` and `UICalendarPopup`.
- `InputConfig`:
  - Now supports `IntlMessages` in texts.
- Improved example.
- mercury_client: ^2.1.6
- intl_messages: ^2.0.3
- dom_tools: ^2.1.3
- dom_builder: ^2.0.10
- mercury_client: ^2.1.6
- build_runner: ^2.1.11
- yaml: ^3.1.1
- args: ^2.3.1

## 2.0.12

- Improve `UIColorPickerInput` and `UIInputTable`.
- `InputConfig`:
  - Added support for `IntlMessages` keys for select options.
  - Added `onChangeListener`.
- `UIRoot`:
  - Add default call to `initializeDateFormatting` while calling `initializeLocale`.
- dom_tools: ^2.1.2

## 2.0.11

- Improved GitHub CI.
- swiss_knife: ^3.1.1
- mercury_client: ^2.1.5
- intl_messages: ^2.0.2
- json_render: ^2.0.4
- archive: ^3.3.0

## 2.0.10

- Added extensions: `ElementExtension`, `IterableElementExtension` and `IterableUIComponentExtension`.
- Improved resolution of `UIComponent` from an `Element`.
- `UINavigator`:
  - Added `equalsToCurrentRoute` and `equalsToCurrentRouteParameters`.
- dom_tools: ^2.1.1
- dom_builder: ^2.0.9

## 2.0.9

- `UIComponent`:
  - New `uiRoot` getter.
  - Improve `parentUIComponent` resolution.
- `UIRoot.renderLoading` now is the default render for loading children `UIComponent`s.
- dependency_validator: ^3.1.0

## 2.0.8

- Dart `2.16`:
  - Organize imports.
  - Fix new lints.
- sdk: '>=2.15.0 <3.0.0'
- json_render: ^2.0.2
- dom_tools: ^2.1.0
- mercury_client: ^2.1.3
- args: ^2.3.0

## 2.0.7

- dom_builder: ^2.0.8

## 2.0.6

- Added helper `$uiLoading`.
- Improved `Element` field name resolution: now also accepts the `name` attribute for `<input>` elements.
- mercury_client: ^2.1.1
- dom_builder: ^2.0.7

## 2.0.5

- Updated `bones_ui_app_template.tar.gz`.

## 2.0.4

- Added CLI `bones_ui`.
  - Added `Bones_UI App` template.
- Re-factor.
  - Files structure.
  - Change from package `pedantic` to `lints`.
- Improve example.

## 2.0.3

- `ui-template`:
  - Allow DOM elements in template.
  - `DSX` integration.
  - Better resolution of variables and blocks.
  - Allow simple variables outside `ui-template`.
- `ui-button`:
  - Added attributes: `loaded-text-class`, `loaded-text-error-class`, `loaded-text-error-classes`, `button-class`
- New registered tag: `ui-svg` 
- dom_builder: ^2.0.6
- swiss_knife: ^3.0.8

## 2.0.2

- swiss_knife: ^3.0.7
- mercury_client: ^2.0.3
- sdk: '>=2.13.0 <3.0.0'

## 2.0.1

- Sound null safety compatibility.
- dynamic_call: ^2.0.1
- mercury_client: ^2.0.1
- intl_messages: ^2.0.1
- dom_tools: ^2.0.1
- json_render: ^2.0.1
- html_unescape: ^2.0.0
- enum_to_string: ^2.0.1
- collection: ^1.15.0

## 2.0.0-nullsafety.0

- Initial compatibility with Null Safety.
- Better render of async content.
- `dom_builder` compatibility.
- removed PWA support (waiting null safety of package `service_worker`). 

## 1.2.0

- `UIComponent`:
  - Optimized performance of `render` call tree.
  - Support to `render` values of type `Future`.
    - Methods `renderLoading` and `renderError` for `Future` values.
  - Improved `getFields` and `parseElementValue` (added `parseChildElementValue`).
  - New fields:
    - `preserveRender`, `subUIComponents`, `subUIComponentsDeeply`, `refreshOnNavigate`.
  - New methods:
    - `getRenderedElementById`, `getRenderedUIComponentById`, `getRenderedUIComponentsByIds`,
    `getRenderedUIComponentByType`, `getRenderedUIComponents`.
    - `isAnyComponentRendering`.
- `UIRoot`:
  - Adde `renderAlert` and `alert`.
  - New `DOMTreeReferenceMap` to control handling of
    `UIRoot` tree of components and `content` elements.
- `UINavigator`:
  - Added `navigateToMainRoute` and `navigableRoutesAndNames`.
- `UIComponentAsync`:
  - Added field `cacheRenderAsync`.
- `UIAsyncContent`:
  - Added `error` field.
  - Now accepts `Function` as content.
- `UILoadingConfig`: improve constructors.
- `UIButtonLoader`:
  - Added properties: `buttonClasses` and `buttonStyle`.
- Helper: `$ui_button_loader`.
- `UIButtonCapturePhoto`:
  - New fields `buttonContent`, `selectedImageClasses`, `selectedImageStyle` and `onlyShowSelectedImageInButton`.
  - Changed to call code moved to `dom_tools`.
- swiss_knife: ^2.5.24
- dynamic_call: ^1.0.16
- mercury_client: ^1.1.16
- intl_messages: ^1.1.13
- dom_tools: ^1.3.20
- dom_builder: ^1.0.24
- json_render: ^1.3.8
- enum_to_string: ^1.0.14

## 1.1.1

- Improved `BUIRender`:
  - Added support for `IntlMessages` keys in the BUI Code: `{{intl:keyX}}`
  - Improve route support.
- Improved `UILoadingConfig`.
- `UIButtonLoader`: using all properties of `UILoadingConfig`.
- `UIDialogBase.show`: ensure that is in DOM.
- `UITemplateElementGenerator`: support to `intl`.
- `UIDOMActionExecutor`: implementation of `callLocale`.
- `UINavigableComponent`: check changed route to notify also when rendering.
- swiss_knife: ^2.5.18
- dynamic_call: ^1.0.14
- mercury_client: ^1.1.13
- intl_messages: ^1.1.12
- dom_tools: ^1.3.15
- dom_builder: ^1.0.22

## 1.1.0

- Added `UIButtonLoader`.
- Added `UIMasonry`.
- Added `UIDocument`.
- Added `UILoading` and loading elements.
- Added `UIDialogInput`.
- Added `htmlAsSvgContent`.
- `UIMultiSelection`: added attribute `multi-selection`.
- Added `BUIRender`: render framework of `bui` files and `bui-manifest` tree.
- Improved `UIDialog` and `UIDialogBase`.
- swiss_knife: ^2.5.16
- dom_tools: ^1.3.14
- dom_builder: ^1.0.20
- json_render: ^1.3.7
- json_object_mapper: ^1.1.3
- Added dependency: archive: ^2.0.13
- Removed dependency `mustache_template`. Using `dom_builder` templates.

## 1.0.20

- Changed library:
  - `bones_ui`: exports only `bones_ui` components and base classes.
  - `bones_ui_kit`: exports `bones_ui` and other packages like  `swiss_knife`,
    `dom_builder`, `dom_tools` and `mercury_client`

## 1.0.19

- `UIInputTable`: `actionListenerComponent` and `actionListener`.
- mercury_client: ^1.1.12

## 1.0.18

- Better behavior of `UINavigableComponent` when `UIRoot` makes the 1st render,
  and the route is not accessible and redirected to another route.
- Fixed navigation to a route not registered yet (when `UIRoot` does the 1st render). 
- Avoid 'loop' of navigations to the same route. 
- swiss_knife: ^2.5.13

## 1.0.17

- Added support to `DataSource` into `UIComponent`.
- Added `UIMenu` and `UIPopupMenu`: Creates a top menu with popups and icons.
- Added `UISVG`: Renders SVG links or tags.
- Added `UIDataSource`: Connects a `DataSource` to `UIComponent`.
- Added `UIColorPickerInput`: A simple and compact color picker component.
- Added placeholder support into `InputConfig`.
- `UIInfosTable`: `headerColumnsNames`, `headerColor`, `rowsStyles`, `cellsStyles`.
- swiss_knife: ^2.5.12
- dynamic_call: ^1.0.12
- mercury_client: ^1.1.10
- intl_messages: ^1.1.10
- dom_tools: ^1.3.9
- dom_builder: ^1.0.17
- json_render: ^1.3.5
- json_object_mapper: ^1.1.2
- mustache_template: ^1.0.0+1

## 1.0.16

- `UIDialog`: handle closing/cancel buttons.
- `UIMultiSelection`: fix when selecting all entries and showing an unnecessary `<hr>`.
    `_allowInputValue` now triggers `onChange`.   
- swiss_knife: ^2.5.7
- mercury_client: ^1.1.9
- dom_tools: ^1.3.5

## 1.0.15

- dartanalyzer.

## 1.0.14

- Refactor: move components implementations to directory `components`.
- Added `UIControlledComponentsetupControllersOnChange`.
- `UIMultiSelection`: mutable options; options panel with scroll bars.
- Usage of `IntlBasicDictionary` for some messages.
- dartfmt.
- swiss_knife: ^2.5.6
- intl_messages: ^1.1.9

## 1.0.13

- Renamed `UIButton` to `UIButtonBase`.
- Renamed `UISimpleButton` to `UIButton`.
- `UIDialog`: improved implementation.
- `UICapture`: Added generic file support.
- dartfmt.
- swiss_knife: ^2.5.5
- dom_tools: ^1.3.4
- dom_builder: ^1.0.13
- json_render: ^1.3.4
- mercury_client: ^1.1.8

## 1.0.12

- Removed UICodeHighlight.
- dom_tools: ^1.3.2
- json_render: ^1.3.3

## 1.0.11

- Remove debugging code: UIConsole.enable();

## 1.0.10

- dom_builder: ^1.0.7
- Update README.md to indicate `bones_ui_bootstrap`. 

## 1.0.9

- Fix README LICENSE title.

## 1.0.8

- dartfmt.
- Fix typos.

## 1.0.7

- Added API Documentation.
- Updated LICENSE.
- UISimpleButton
- UIButtonCapturePhoto
- UICapture: now handles loaded data and converts to a CaptureDataFormat type.
- UIExplorer: modelType catalog.
- UIComponent: better automatic resolution of parentUIComponent
- UIComponent: fields are views now. Removed UIComponent._fields Map.
- InputConfig: now renders the components (moved from UIInputTable).
- getLanguageByExtension(): fixed markdown extension.
- json_render: ^1.3.2
- dom_tools: ^1.3.1
- dom_builder: ^1.0.6
- intl_messages: ^1.1.8
- mercury_client: ^1.1.7
- swiss_knife: ^2.5.2

## 1.0.6

- UIRoot with better load of locales.
- UIComponent._parentUIComponent better populated.
- UIComponent.isShowing
- UIComponent.isRendered() -> UIComponent.isRendered
- UIAsyncContent doesn't accept anymore as sub content another UIAsyncContent (throws StateError). 
- UIInputTable now when re-rendering respects previous set values.
- UIRoot.buildAppStatusBar()
- getLanguageByExtension()
- mercury_client: ^1.1.4
- swiss_knife: ^2.3.9
- intl_messages: ^1.1.6
- dom_tools: ^1.2.7
- json_render: ^1.2.7
- yaml: ^2.2.0

## 1.0.5

- UIComponent: accepts null parent (will be set when rendered by parent).
- UIComponent.onChange: should be called every time a component status changes or interactive event happens.
- UIAsyncContent.equalsProperties() now makes deep check.
- UIControlledComponent
- UIComponentAsync
- swiss_knife: ^2.3.8

## 1.0.4

- UIComponent.isRendering
- UIMultiSelection: fix options panel position on window resize. onTouchEnter/onTouchLeave
- UINavigableComponent: alerts/exception for empty route.
- dom_tools: ^1.2.6
- swiss_knife: ^2.3.7
- intl_messages: ^1.1.5

## 1.0.3

- UIComponent.parentUIComponent
- UIComponent.onChildRendered()
- Navigation.parameterAsInt/parameterAsNum/parameterAsBool
- Navigation.parameterAsStringList/parameterAsIntList/parameterAsNumList/parameterAsBoolList
- UINavigator._encodeRouteParameters(): Comma ',' won't be encoded as %2C
- swiss_knife: ^2.3.5

## 1.0.2

- of prefix 'ui-' for css.

## 1.0.1

- UIAsyncContent.isValid(properties]): properties optional.
- Declaration of UIRoot.renderMenu() optional. 

## 1.0.0

- Initial version, created by Graciliano M. P. (Jan 2019)
