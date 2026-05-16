module Dictionary exposing (run)

import BackendTask exposing (BackendTask)
import BackendTask.File
import FatalError exposing (FatalError)
import Json.Decode as Decode exposing (Decoder)
import Pages.Script exposing (Script)
import Tui
import Tui.Layout as Layout
import Tui.Layout.Effect as Effect exposing (Effect)
import Tui.Screen


type alias Entry =
    { word : String, definition : String }


type alias Model =
    { entries : List Entry
    , selected : Maybe Entry
    }


type Msg
    = Select Entry


dictionary : BackendTask FatalError (List Entry)
dictionary =
    BackendTask.File.jsonFile
        (Decode.list
            (Decode.map2 Entry
                (Decode.field "word" Decode.string)
                (Decode.field "definition" Decode.string)
            )
        )
        "dictionary.json"
        |> BackendTask.allowFatal


run : Script
run =
    Layout.program
        { data = dictionary
        , init = \entries -> ( { entries = entries, selected = Nothing }, Effect.none )
        , update = update
        , view = view
        }
        |> Layout.toScript


update : Layout.UpdateContext -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        Select entry ->
            ( { model | selected = Just entry }, Effect.none )


view : Tui.Context -> Model -> Layout.Layout Msg
view _ model =
    Layout.horizontal
        [ Layout.pane "words"
            { title = "Words", width = Layout.fill }
            (Layout.selectableList
                { onSelect = Select
                , view = \entry -> Tui.Screen.text entry.word
                }
                model.entries
            )
        , Layout.pane "definition"
            { title = "Definition", width = Layout.fillPortion 2 }
            (Layout.paragraph
                (model.selected
                    |> Maybe.map .definition
                    |> Maybe.withDefault ""
                )
            )
        ]
