define('$injectJS', [], function() {
    injector.strict_dependency_providers = false;
    function parserFactory(equalityCriterionPattern, existenceCriterionPattern, selectMultiplePattern, criteriaJoinPattern) {
        function parseCriterion(text) {
            var matches = text.match(existenceCriterionPattern);
            if (matches === null) {
                matches = text.match(equalityCriterionPattern);
            }

            if (!!matches) {
                matches[2] = matches[2].replace(/\s+/, '').replace(/null/i, 'NULL');
            } else {
                return parseMultiselectCriterion(text);
            }

            var equalityMapper = {
                '=': 'resp_equals',
                '!=': 'resp_notequals',
                '>': 'resp_greater',
                '<': 'resp_less',
                '>=': 'resp_greaterequals',
                '<=': 'resp_lessequals',
                "!=''": 'ans_notnull',
                "=''": 'ans_null'
            };

            var res = {
                name: matches[1],
                operator: equalityMapper[matches[2]]
            };

            if (matches[3]) {
                res.response_value = matches[3].replace(/date\('(\d{4}-\d{2}-\d{2})'\)/, '$1');
            }

            return res;
        }

        function parseMultiselectCriterion(text) {
            var matches = text.match(selectMultiplePattern);

            if (!matches) {
                throw new Error('criterion not recognized: "' + text + '"');
            }

            return {
                name: matches[1],
                operator: text.indexOf('not(') == -1 ? 'multiplechoice_selected' : 'multiplechoice_notselected',
                response_value: matches[2]
            };
        }

        return function (text) {
            var criteria = text.split(criteriaJoinPattern),
                criteriaLength = criteria.length,
                joinOperators = text.match(criteriaJoinPattern);


            if (!!joinOperators && _.uniq(joinOperators).length > 1) {
                throw new Error('multiple criteria join operators are not supported at the moment');
            }

            if (criteriaLength === 1) {
                return {
                    criteria: [parseCriterion(text)]
                };
            } else {
                return {
                    criteria: _.map(criteria, function (criterion) {
                        return parseCriterion(criterion);
                    }),
                    operator: joinOperators[0].replace(/ /g, '').toUpperCase()
                };
            }
        };
    }

    injector.registerType(
        'ValidationLogic/Parser',
        function () {
            this.parse = parserFactory(
                /(\.)\s*(=|!=|<|>|<=|>=)\s*\'?((?:date\(\'\d{4}-\d{2}-\d{2}\'\)|[\s\w]+|-?\d+)\.?\d*)\'?/,
                /(\.)\s*((?:=|!=)\s*(?:NULL|''))/i,
                /selected\((\.)\s*,\s*\'(\w+)\'\)/,
                / and | or /gi
            );
        },
        'singleton'
    );
    injector.registerType(
        'SkipLogic/Parser',
        function () {
            this.parse = parserFactory(
                /^\${(\w+)}\s*(=|!=|<|>|<=|>=)\s*\'?((?:date\(\'\d{4}-\d{2}-\d{2}\'\)|[\s\w]+|-?\d+)\.?\d*)\'?/,
                /\${(\w+)}\s*((?:=|!=)\s*(?:NULL|''))/i,
                /selected\(\$\{(\w+)\},\s*\'(\w+)\'\)/,
                / and | or /gi
            );
        },
        'singleton'
    );
    return injector;
});
