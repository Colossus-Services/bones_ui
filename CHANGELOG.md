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
