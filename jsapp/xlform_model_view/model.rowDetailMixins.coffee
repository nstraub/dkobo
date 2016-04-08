define 'cs!xlform/model.rowDetailMixins', [
        'cs!xlform/model.utils',
        '$injectJS'
        ], (
            $modelUtils,
            $injectJS
            )->
  # To be extended ontop of a RowDetail when the key matches
  # the attribute in XLF.RowDetailMixin
  SkipLogicDetailMixin =
    getValue: ()->
      v = @serialize()
      if v is "undefined"
        trackJs?.console.error("Serialized value is returning a string, undefined")
        v = ""
      v

    postInitialize: ()->
      @facade = $injectJS.get('SkipLogic/Facade', @, {current_question: @_parent, serialized_criteria: @.get('value')})

    serialize: ()->
      # @hidden = false
      # note: reimplement "hidden" if response is invalid
      @facade.serialize()

    parse: ()->

    linkUp: (ctx)->
      @facade.initialize()

  ValidationLogicMixin =
    getValue: () ->
      v = @serialize()
      if v is "undefined"
        trackJs?.console.error("Serialized value is returning a string, undefined")
        v = ""
      v

    postInitialize: () ->
      @facade = $injectJS.get('SkipLogic/Facade', @, {current_question: @_parent, serialized_criteria: @.get('value')})

    serialize: ()->
      # @hidden = false
      # note: reimplement "hidden" if response is invalid
      @facade.serialize()

    parse: ()->

    linkUp: (ctx)->
      @facade.initialize()

  rowDetailMixins =
    relevant: SkipLogicDetailMixin
    constraint: ValidationLogicMixin
    label:
      postInitialize: ()->
        # When the row's name changes, trigger the row's [finalize] function.
        return
    name:
      deduplicate: (survey) ->
        names = []
        survey.forEachRow (r)=>
          if r.get('name') != @
            name = r.getValue("name")
            names.push(name)
        , includeGroups: true

        $modelUtils.sluggifyLabel @get('value'), names
  rowDetailMixins
