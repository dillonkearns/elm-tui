module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import Docs.NoMissing exposing (exposedModules, onlyExposed)
import Docs.ReviewAtDocs
import Docs.ReviewLinksAndSections
import Docs.UpToDateReadmeLinks
import NoDebug.Log
import NoDebug.TodoOrToString
import NoExposingEverything
import NoMissingTypeAnnotation
import NoModuleOnExposedNames
import NoUnused.CustomTypeConstructorArgs
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ NoUnused.Modules.rule
        |> Review.Rule.ignoreErrorsForDirectories [ "tests" ]
    , NoUnused.Exports.rule
        |> Review.Rule.ignoreErrorsForDirectories [ "tests" ]
    , NoUnused.Dependencies.rule
    , NoUnused.CustomTypeConstructorArgs.rule
        |> Review.Rule.ignoreErrorsForDirectories [ "tests" ]
    , NoUnused.Parameters.rule
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
        |> Review.Rule.ignoreErrorsForDirectories [ "tests" ]
    , NoExposingEverything.rule
    , NoMissingTypeAnnotation.rule
        |> Review.Rule.ignoreErrorsForDirectories [ "tests" ]
    , NoModuleOnExposedNames.rule
        -- Tui.Layout.Effect re-exports the Internal Effect type as a type
        -- alias of the same name; the rule's auto-fix would shadow it into
        -- a recursive alias. Reference: src/Tui/Layout/Effect.elm.
        |> Review.Rule.ignoreErrorsForFiles [ "src/Tui/Layout/Effect.elm" ]
    , Docs.NoMissing.rule
        { document = onlyExposed
        , from = exposedModules
        }
    , Docs.ReviewLinksAndSections.rule
    , Docs.ReviewAtDocs.rule
    , Docs.UpToDateReadmeLinks.rule
    ]
        |> List.map
            (\rule ->
                rule
                    |> Review.Rule.ignoreErrorsForDirectories
                        [ "tests/VerifyExamples"
                        ]
            )
