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
