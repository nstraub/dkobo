define 'cs!xlform/view.widgets', [
        'backbone',
        '$injectJS'
        ], (
            Backbone,
            $injectJS
            )->

  viewWidgets = {}

  class viewWidgets.Base extends Backbone.View
    attach_to: ($el) ->
      if $el instanceof viewWidgets.Base
        $el = $el.$el
      $el.append(@el)

    bind_event: (type, callback) ->
      @$el.off type, callback
      @$el.on type, callback
    detach: () ->
      @$el.remove()
    val: (value) ->
      if value
        @$el.val value
        if !@$el.val()?
          @$el.prop('selectedIndex', 0);
      else return @$el.val()

  class viewWidgets.Label extends viewWidgets.Base
    tagName: 'label'
    constructor: (@text, @className, @input) ->
      super()
    val: () ->
    bind_event: () ->
    render: () ->
      if @text
        @$el.text(@text)
      if @className
        @$el.addClass @className
      if @input
        @$el.attr 'for', @input.cid
      @
    $inject: ['text', 'className', 'input']

    $injectJS.registerType('Widgets/Label', Label)

  class viewWidgets.EmptyView extends viewWidgets.Base
    attach_to: () -> return
    val: () -> return
    bind_event: () -> return
    render: () -> @
    val: () -> null

    $injectJS.registerType('Widgets/Empty', EmptyView)

  class viewWidgets.TextArea extends viewWidgets.Base
    tagName: 'textarea'
    render: () ->
      @$el.val @text
      @$el.addClass @className
      @$el.on 'paste', (e) -> e.stopPropagation()

      @
    constructor: (@text, @className) -> super()
    $inject: ['text', 'className']

    $injectJS.registerType('Widgets/TextArea', TextArea)

  class viewWidgets.TextBox extends viewWidgets.Base
    tagName: 'input'
    render: () ->
      @$el.attr 'type', 'text'
      @$el.val @text
      @$el.addClass @className
      @$el.attr 'placeholder', @placeholder
      @$el.on 'paste', (e) -> e.stopPropagation()

      @
    constructor: (@text, @className, @placeholder) -> super()
    $inject: ['text', 'className', 'placeholder']

    $injectJS.registerType('Widgets/TextBox', TextBox)

  class viewWidgets.Button extends viewWidgets.Base
    tagName: 'button'
    render: () ->
      @$el.html @text
      @$el.addClass @className

      @
    constructor: (@text, @className) -> super()
    $inject: ['text', 'className']

    $injectJS.registerType('Widgets/Button', Button)

  class viewWidgets.DropDownModel extends Backbone.Model

  class viewWidgets.DropDown extends viewWidgets.Base
    tagName: 'select'
    constructor: (@options) ->
      super
      if !(@options instanceof viewWidgets.DropDownModel)
        @options = new viewWidgets.DropDownModel()
        @options.set 'options', options
      @options.on 'change:options', @render.bind(@)
    render: () =>
      options = ''
      _.each @options.get('options'), (option) ->
        options += '<option value="' + option.value + '">' + option.text + '</option>'

      @$el.html options
      @

    attach_to: (target) ->
      super(target)
      @$el.select2({ minimumResultsForSearch: -1 })

    $inject: 'options'

    $injectJS.registerType('Widgets/DropDown', DropDown)

  viewWidgets
