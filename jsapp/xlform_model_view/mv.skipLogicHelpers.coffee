define 'cs!xlform/mv.skipLogicHelpers', [
        'xlform/model.skipLogicParser',
        '$injectJS'
        ], (
            $skipLogicParser,
            $injectJS
            )->

  skipLogicHelpers = {}

  ###----------------------------------------------------------------------------------------------------------###
  #-- deprecated, $injectJS is used instead
  ###----------------------------------------------------------------------------------------------------------###

  class skipLogicHelpers.SkipLogicHelperFactory

  class skipLogicHelpers.SkipLogicPresentationFacade
    constructor: (@context) ->
    initialize: () ->
    serialize: () ->
      return @context.serialize()
    render: (target) ->
      @context.render target

    $injectJS.registerType('SkipLogic/Facade', ['SkipLogic/Helpers/Context', SkipLogicPresentationFacade])

  class skipLogicHelpers.SkipLogicPresenter
    constructor: (@model, @view, @current_question, @survey) ->
      @view.presenter = @
      if @survey
        update_choice_list = (cid) =>
          question = @model._get_question()
          if question._isSelectQuestion() && question.getList().cid == cid

            current_response_value = @model.get('response_value').get('cid')

            if !question.getList().options.get current_response_value
              @dispatcher.trigger 'remove:presenter', @model.cid
            else
              options = _.map question.getList().options.models, (response) ->
                text: response.get('label')
                value: response.cid

              response_picker_model = @view.response_value_view.options

              response_picker_model.set 'options', options
              @view.response_value_view.val(current_response_value)
              @view.response_value_view.$el.trigger('change')
              @model.change_response current_response_value

        @survey.on 'choice-list-update', update_choice_list, @

        @survey.on 'remove-option', update_choice_list, @

        @survey.on 'row-detail-change', (row, key) =>
          if @destination
            if key == 'label'
              @render(@destination)
        , @
      else
        console.error "this.survey is not yet available"

    change_question: (question_name) ->
      @model.change_question question_name

      @question = @model._get_question()
      question_type = @question.get_type()
      @question.on 'remove', () =>
        @dispatcher.trigger 'remove:presenter', @model.cid

      @view.change_operator $injectJS.get('SkipLogic/View/OperatorPicker', null, {question_type})
      @view.operator_picker_view.val @model.get('operator').get_value()
      @view.attach_operator()

      @change_response_view question_type, @model.get('operator').get_type()

      @finish_changing()

    change_operator: (operator_id) ->
      @model.change_operator operator_id

      @change_response_view @model._get_question().get_type(), @model.get('operator').get_type()

      @finish_changing()

    change_response: (response_text) ->
      @model.change_response response_text
      @finish_changing()

    change_response_view: (question_type, operator_type) ->
      response_view = $injectJS.get('SkipLogic/View/Response', null, {question: @model._get_question(), question_type, operator_type})
      response_view.model = @model.get 'response_value'

      @view.change_response response_view
      @view.attach_response()

      response_value = response_view.model.get('value')

      question = @model._get_question()
      if (question._isSelectQuestion())
        response_value = _.find(question.getList().options.models, (option) ->
          option.get('name') == response_value).cid

      @view.response_value_view.val response_value
      response_view.$el.trigger('change')


    finish_changing: () ->
      @dispatcher.trigger 'changed:model', @

    is_valid: () ->
      if !@model._get_question()
        return false
      else if @model.get('operator').get_type().id == 1
        return true
      else if @model.get('response_value').get('value')  in ['', undefined] || @model.get('response_value').isValid() == false
        return false
      else
        return true

    render: (@destination) ->
      @view.question_picker_view.detach()
      @view.question_picker_view = $injectJS.get('SkipLogic/View/QuestionPicker', @survey, {@current_question})
      @view.render()
      @view.question_picker_view.val @model.get('question_cid')
      @view.operator_picker_view.val @model.get('operator').get_value()
      response_value = @model.get('response_value')?.get('value')

      question = @model._get_question()
      if (question && question._isSelectQuestion())
        response_value = _.find(question.getList().options.models, (option) ->
          option.get('name') == response_value)?.cid
      @view.response_value_view.val response_value
      @view.attach_to destination



      @dispatcher.trigger 'rendered', @

    serialize: () ->
      @model.serialize()

    $inject: ['SkipLogic/Model/Criterion', 'SkipLogic/View/Criterion', 'current_question', 'survey']

    $injectJS.registerType('SkipLogic/Helpers/Presenter', SkipLogicPresenter)

  class skipLogicHelpers.SkipLogicBuilder
    constructor: (@survey, @current_question) -> return
    build_criterion_builder: (serialized_criteria) ->
      if serialized_criteria == ''
        return [[@build_empty_criterion()], 'and']

      try
        parsed = @_parse_skip_logic_criteria serialized_criteria

        criteria = _.filter(_.map(parsed.criteria, (criterion) =>
            @criterion = criterion
            @build_criterion()
          )
        , (item) -> !!item)
        if criteria.length == 0
          criteria.push @build_empty_criterion()

      catch e
        trackJs?.console.log("SkipLogic cell: #{serialized_criteria}")
        trackJs?.console.error("could not parse skip logic. falling back to hand-coded")
        return false
      return [criteria, parsed.operator]

    _parse_skip_logic_criteria: (criteria) ->
      return $skipLogicParser criteria

    _operator_type: () ->
      return _.find skipLogicHelpers.operator_types, (op_type) =>
          @criterion?.operator in op_type.parser_name

    build_criterion: () =>
      question = @_get_question()
      if !question
        return false

      if !(question in @questions())
        throw 'question is not selectable'

      question_type = question.get_type()

      operator_type = @_operator_type()

      presenter = $injectJS.get(
        'SkipLogic/Helpers/Presenter',
        @survey,
        {
          operator_parser_name: (if operator_type.type == 'existence' then 'existence' else question_type.equality_operator_type),
          operator_symbol: operator_type.symbol[@criterion.operator],
          operator_type_id: operator_type.id
          operator_type
          question
          question_type
          @current_question
        }
      )

      presenter.model.change_question question.cid

      response_value = if question._isSelectQuestion() then _.find(question.getList().options.models, (option) => return option.get('name') == @criterion.response_value)?.cid else @criterion.response_value
      presenter.model.change_response response_value || ''
      presenter.view.response_value_view.model = presenter.model.get 'response_value'
      presenter.view.response_value_view.val(response_value)

      return presenter
    _get_question: () ->
      @survey.findRowByName @criterion.name

    build_empty_criterion: () =>

      return $injectJS.get(
        'SkipLogic/Helpers/Presenter',
        @survey,
        {
          operator_parser_name: 'empty'
          @current_question
        }
      )

    questions: () ->
      @selectable = @current_question.selectableRows() || @selectable
      return @selectable

    $inject: ['survey', 'current_question']

    $injectJS.registerType('SkipLogic/Helpers/Builder', SkipLogicBuilder, 'root')

  ###----------------------------------------------------------------------------------------------------------###
  #-- Presentation.RowDetail.SkipLogic.State.coffee
  ###----------------------------------------------------------------------------------------------------------###

  class skipLogicHelpers.SkipLogicHelperContext
    render: (@destination) ->
      if @destination?
        @destination.empty()
        @state.render destination
      return
    serialize: () ->
      return @state.serialize()
    use_criterion_builder_helper: () ->
      presenters = @builder.build_criterion_builder(@state.serialize())

      if presenters == false
        @state = null
      else
        @state = new skipLogicHelpers.SkipLogicCriterionBuilderHelper(presenters[0], presenters[1], @builder, @)
        @render @destination
      return
    use_hand_code_helper: () ->
      @state = new skipLogicHelpers.SkipLogicHandCodeHelper(@state.serialize(), @builder, @)
      @render @destination
      return
    use_mode_selector_helper : () ->
      @survey.off null, null, @state
      @state = new skipLogicHelpers.SkipLogicModeSelectorHelper(@)
      @render @destination
      return
    constructor: (@builder, serialized_criteria, @survey) ->
      @state = serialize: () -> return serialized_criteria
      if !serialized_criteria? || serialized_criteria == ''
        serialized_criteria = ''
        @use_mode_selector_helper()
      else
        @use_criterion_builder_helper()

      if !@state?
        @state = serialize: () -> return serialized_criteria
        @use_hand_code_helper()

    $inject: ['SkipLogic/Helpers/Builder', 'serialized_criteria', 'survey']

    $injectJS.registerType('SkipLogic/Helpers/Context', SkipLogicHelperContext, 'root')

  class skipLogicHelpers.SkipLogicCriterionBuilderHelper
    determine_criterion_delimiter_visibility: () ->
      if @presenters.length < 2
        @$criterion_delimiter.hide()
      else
        @$criterion_delimiter.show()
    render: (destination) ->
      @view.render().attach_to destination
      @$criterion_delimiter = @view.$(".skiplogic__delimselect")
      @$add_new_criterion_button = @view.$('.skiplogic__addcriterion')

      @determine_criterion_delimiter_visibility()

      @destination = @view.$('.skiplogic__criterialist')

      _.each @presenters, (presenter) =>
        presenter.render @destination

    serialize: () ->
      serialized = _.map @presenters, (presenter) ->
        presenter.serialize()
      _.filter(serialized, (crit) -> crit).join(' ' + @view.criterion_delimiter + ' ')
    add_empty: () ->
      presenter = @builder.build_empty_criterion()
      presenter.dispatcher = @dispatcher
      presenter.serialize_all = _.bind @serialize, @
      @presenters.push presenter
      presenter.render @destination
      @determine_criterion_delimiter_visibility()
    remove: (id) ->
      _.each @presenters, (presenter, index) =>
        if presenter? && presenter.model.cid == id
          presenter = @presenters.splice(index, 1)[0]
          presenter.view.$el.remove()
          @builder.survey.off null, null, presenter
          @determine_add_new_criterion_visibility()

      if @presenters.length == 0
        @context.use_mode_selector_helper()

    determine_add_new_criterion_visibility: () ->
      if @all_presenters_are_valid()
        action = 'show()'
        @$add_new_criterion_button?.show()
      else
        action = 'hide()'
        @$add_new_criterion_button?.hide()

      if !@$add_new_criterion_button
        trackJs?.console.error("@$add_new_criterion_button is not defined. cannot call #{action} [inside of determine_add_new_criterion_visibility]")

    constructor: (@presenters, separator, @builder, @context) ->
      @view = $injectJS.get('SkipLogic/View/CriterionBuilder')
      @view.criterion_delimiter = (separator || 'and').toLowerCase()
      @view.facade = @
      @dispatcher = _.clone Backbone.Events
      @dispatcher.on 'remove:presenter', (cid) =>
        @remove cid


      @dispatcher.on 'changed:model', (presenter) =>
        @determine_add_new_criterion_visibility()

      @dispatcher.on 'rendered', (presenter) =>
        @determine_add_new_criterion_visibility()

      removeInvalidPresenters = () =>
        questions = builder.questions()
        presenters_to_be_removed = []
        _.each @presenters, (presenter) =>
          if presenter.model._get_question() && !(presenter.model._get_question() in questions)
            presenters_to_be_removed.push presenter.model.cid

        for presenter in presenters_to_be_removed
          @remove presenter

        if @presenters.length == 0
          @context.use_mode_selector_helper()

      @builder.survey.on 'sortablestop', removeInvalidPresenters, @

      removeInvalidPresenters()

      _.each @presenters, (presenter) =>
        presenter.dispatcher = @dispatcher
        presenter.serialize_all = _.bind @serialize, @

    all_presenters_are_valid: () ->
        return !_.find @presenters, (presenter) -> !presenter.is_valid()

    switch_editing_mode: () ->
      @builder.build_hand_code_criteria @serialize()

  class skipLogicHelpers.SkipLogicHandCodeHelper
    render: ($destination) ->
      $destination.append @$parent
      @textarea.render().attach_to @$parent
      @button.render().attach_to @$parent
      @button.bind_event 'click', () => @context.use_mode_selector_helper()
    serialize: () ->
      @textarea.$el.val() || @criteria
    constructor: (@criteria, @builder, @context) ->
      @$parent = $('<div>')
      @textarea = $injectJS.get('Widgets/TextArea', null, {text: @criteria, className: 'skiplogic__handcode-edit'})
      @button = $injectJS.get('Widgets/Button', null, {text: 'x', className: 'skiplogic-handcode__cancel'})

  class skipLogicHelpers.SkipLogicModeSelectorHelper
    render: ($destination) ->
      $parent = $('<div>')
      $destination.append $parent
      @criterion_builder_button.render().attach_to $parent
      @handcode_button.render().attach_to $parent

      @criterion_builder_button.bind_event 'click', () => @context.use_criterion_builder_helper()
      @handcode_button.bind_event 'click', () => @context.use_hand_code_helper()

    serialize: () ->
      return ''
    constructor: (@context) ->
      @criterion_builder_button = $injectJS.get 'Widgets/Button', null, {text: '<i class="fa fa-plus"></i> Add a condition', className: 'skiplogic__button skiplogic__select-builder'}
      @handcode_button = $injectJS.get 'Widgets/Button', null, {text: '<i>${}</i> Manually enter your skip logic in XLSForm code', className: 'skiplogic__button skiplogic__select-handcode'}
    switch_editing_mode: () -> return

  operators =
    EXISTENCE: 1
    EQUALITY: 2
    GREATER_THAN: 3
    GREATER_THAN_EQ: 4
  ops =
    EX: operators.EXISTENCE
    EQ: operators.EQUALITY
    GT: operators.GREATER_THAN
    GE: operators.GREATER_THAN_EQ

  skipLogicHelpers.question_types =
    default:
      operators: [
        ops.EX #1
        ops.EQ #2
      ]
      equality_operator_type: 'text'
      response_type: 'text'
      name: 'default'
    select_one:
      operators: [
        ops.EQ #2
        ops.EX #1
      ]
      equality_operator_type: 'text'
      response_type: 'dropdown'
      name: 'select_one'
    select_multiple:
      operators: [
        ops.EQ #2
        ops.EX #1
      ]
      equality_operator_type: 'select_multiple'
      response_type: 'dropdown'
      name: 'select_multiple'
    integer:
      operators: [
        ops.GT #3
        ops.EX #1
        ops.EQ #2
        ops.GE #4
      ]
      equality_operator_type: 'basic'
      response_type: 'integer'
      name: 'integer'
    rank:
      operators: [
        ops.EX #1
        ops.EQ #2
      ]
      equality_operator_type: 'select_multiple'
      response_type: 'dropdown'
      name: 'rank'
    rank__item:
      operators: [
        ops.EX #1
        ops.EQ #2
      ]
      equality_operator_type: 'select_multiple'
      response_type: 'dropdown'
      name: 'rank_item'

    score:
      operators: [
        ops.EX #1
        ops.EQ #2
      ]
      equality_operator_type: 'select_multiple'
      response_type: 'dropdown'
      name: 'score'
    score__row:
      operators: [
        ops.EX #1
        ops.EQ #2
      ]
      equality_operator_type: 'select_multiple'
      response_type: 'dropdown'
      name: 'score_row'

    barcode:
      operators: [
        ops.GT #3
        ops.EX #1
        ops.EQ #2
        ops.GE #4
      ]
      equality_operator_type: 'text'
      response_type: 'text'
      name: 'barcode'
    decimal:
      operators: [
        ops.EX #1
        ops.EQ #2
        ops.GT #3
        ops.GE #4
      ]
      equality_operator_type: 'basic'
      response_type: 'decimal'
      name: 'decimal'
    geopoint:
      operators: [
        ops.EX #1
      ]
      name: 'geopoint'
    image:
      operators: [
        ops.EX #1
      ]
      name: 'image'
    audio:
      operators: [
        ops.EX #1
      ]
      name: 'audio'
    video:
      operators: [
        ops.EX #1
      ]
      name: 'video'
    acknowledge:
      operators: [
        ops.EX #1
      ]
      name: 'acknowledge'
    date:
      operators: [
        ops.EQ #2
        ops.GT #3
        ops.GE #4
      ]
      equality_operator_type: 'date'
      response_type: 'text'
      name: 'date'


  skipLogicHelpers.operator_types = [
    {
      id: 1
      type: 'existence'
      label: 'Was Answered'
      negated_label: 'Was not Answered'
      abbreviated_label: 'Was Answered'
      abbreviated_negated_label: 'Was not Answered'
      parser_name: ['ans_notnull','ans_null']
      symbol: {
        ans_notnull: '!=',
        ans_null: '='
      }
      response_type: 'empty'
    }
    {
      id: 2
      type: 'equality'
      label: ''
      negated_label: 'not'
      abbreviated_label: '='
      abbreviated_negated_label: '!='
      parser_name: ['resp_equals', 'resp_notequals', 'multiplechoice_selected', 'multiplechoice_notselected']
      symbol: {
        resp_equals: '=',
        resp_notequals: '!=',
        multiplechoice_selected: '='
        multiplechoice_notselected: '!='
      }
    }
    {
      id: 3
      type: 'equality'
      label: 'Greater Than'
      negated_label: 'Less Than'
      abbreviated_label: '>'
      abbreviated_negated_label: '<'
      parser_name: ['resp_greater', 'resp_less']
      symbol: {
        resp_greater: '>'
        resp_less: '<'
      }
    }
    {
      id: 4
      type: 'equality'
      label: 'Greater Than or Equal to'
      negated_label: 'Less Than or Equal to'
      abbreviated_label: '>='
      abbreviated_negated_label: '<='
      parser_name: ['resp_greaterequals', 'resp_lessequals']
      symbol: {
        resp_greaterequals: '>=',
        resp_lessequals: '<='
      }
    }
  ]

  $injectJS.registerProvider('operator_types', ['index', (index)-> skipLogicHelpers.operator_types[index]])

  skipLogicHelpers
