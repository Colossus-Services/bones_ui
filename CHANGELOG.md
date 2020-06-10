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
