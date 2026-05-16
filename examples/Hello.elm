module Hello exposing (run)

import BackendTask
import Pages.Script exposing (Script)
import Tui
import Tui.Layout as Layout
import Tui.Layout.Effect as Effect exposing (Effect)
import Tui.Screen


type alias Item =
    { sha : String, message : String }


{-| The only state this app needs. Selection lives in the framework's
layout state; `selectedItem` is kept in sync automatically because
`Layout.program` fires `onSelect` for the focused pane's initial
selection at startup (and on every navigation after that). There is no
init-time "forgot to set the selected item" bug to introduce.
-}
type alias Model =
    { selectedItem : Maybe Item
    , modal : Maybe ModalState
    }


type ModalState
    = CommitDialog
    | HelpDialog


type Msg
    = SelectItem Item
    | OpenCommit
    | OpenHelp
    | CloseModal
    | SubmitCommit String
    | Quit


items : List Item
items =
    [ { sha = "a1b2c3d", message = "Hello!" }
    , { sha = "e4f5a6b", message = "Goodbye!" }
    ]


run : Script
run =
    Layout.program
        { data = BackendTask.succeed ()
        , init = \_ -> ( { selectedItem = Nothing, modal = Nothing }, Effect.none )
        , update = update
        , view = view
        , bindings = bindings
        , status = \_ -> { waiting = Nothing }
        , modal = modal
        , onRawEvent = Nothing
        }
        |> Tui.program
        |> Tui.toScript


update : Layout.UpdateContext -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        SelectItem item ->
            ( { model | selectedItem = Just item }, Effect.none )

        OpenCommit ->
            ( { model | modal = Just CommitDialog }, Effect.none )

        OpenHelp ->
            ( { model | modal = Just HelpDialog }, Effect.none )

        CloseModal ->
            ( { model | modal = Nothing }, Effect.none )

        SubmitCommit _ ->
            ( { model | modal = Nothing }, Effect.none )

        Quit ->
            ( model, Effect.exit )


view : Tui.Context -> Model -> Layout.Layout Msg
view _ model =
    Layout.horizontal
        [ Layout.pane "items"
            { title = "Items", width = Layout.fill }
            (Layout.selectableList
                { onSelect = SelectItem
                , view = \item -> Tui.Screen.text item.message
                }
                items
            )
        , Layout.pane "detail"
            { title = "Detail", width = Layout.fill }
            (Layout.content
                [ Tui.Screen.text
                    (model.selectedItem
                        |> Maybe.map .message
                        |> Maybe.withDefault ""
                    )
                ]
            )
        ]


bindings : { focusedPane : Maybe String } -> Model -> List (Layout.Group Msg)
bindings _ _ =
    [ Layout.group "Global"
        [ Layout.charBinding 'q' "Quit" Quit
        , Layout.charBinding 'c' "Commit" OpenCommit
        , Layout.charBinding '?' "Help" OpenHelp
        ]
    ]


modal : Model -> Maybe (Layout.Modal Msg)
modal model =
    case model.modal of
        Just CommitDialog ->
            Just
                (Layout.promptModal
                    { title = "Commit"
                    , initialValue = ""
                    , onSubmit = SubmitCommit
                    , onCancel = CloseModal
                    }
                )

        Just HelpDialog ->
            Just (Layout.helpModal CloseModal)

        Nothing ->
            Nothing
