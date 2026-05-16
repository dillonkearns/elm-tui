module MiniGit exposing
    ( miniGitProgram
    , miniGitTest
    , run
    , sampleCommits
    )

import BackendTask
import Pages.Script exposing (Script)
import Test.BackendTask as BackendTaskTest
import Test.Tui as TuiTest
import Tui
import Tui.Layout as Layout
import Tui.Layout.Effect as Effect exposing (Effect)
import Tui.Screen


type alias Commit =
    { sha : String, message : String }


{-| The whole app model. Selection lives in the framework's layout state;
`selectedCommit` is kept in sync automatically because `Layout.program`
fires `onSelect` for the focused pane's initial selection at startup (and
on every navigation after). The diff pane is derived from it, so there is
no "stale diff on init" bug to introduce.
-}
type alias Model =
    { selectedCommit : Maybe Commit
    , modal : Maybe ModalState
    }


type ModalState
    = CommitDialog


type Msg
    = SelectCommit Commit
    | OpenCommit
    | CloseModal
    | SubmitCommit String


sampleCommits : List Commit
sampleCommits =
    [ { sha = "abc1234", message = "Initial commit" }
    , { sha = "def5678", message = "Add feature" }
    , { sha = "345cdef", message = "Fix bug" }
    , { sha = "789abcd", message = "Update docs" }
    , { sha = "aaa1111", message = "Refactor" }
    , { sha = "bbb2222", message = "Add tests" }
    ]


diffForCommit : String -> String
diffForCommit sha =
    "commit "
        ++ sha
        ++ "\nAuthor: Test\nDate: today\n\n    Message for "
        ++ sha
        ++ "\n---\n"
        ++ (List.range 1 40
                |> List.map (\i -> "+ line " ++ String.fromInt i ++ " of diff for " ++ sha)
                |> String.join "\n"
           )


miniGitProgram : Tui.ProgramConfig () (Layout.FrameworkModel Model Msg) (Layout.FrameworkMsg Msg)
miniGitProgram =
    Layout.program
        { data = BackendTask.succeed ()
        , init = \_ -> ( { selectedCommit = Nothing, modal = Nothing }, Effect.none )
        , update = update
        , view = view
        , bindings = bindings
        , status = \_ -> { waiting = Nothing }
        , modal = modal
        , onRawEvent = Nothing
        }


run : Script
run =
    miniGitProgram
        |> Tui.program
        |> Tui.toScript


update : Layout.UpdateContext -> Msg -> Model -> ( Model, Effect Msg )
update _ msg model =
    case msg of
        SelectCommit commit ->
            -- Navigating to a different commit scrolls the diff back to the top.
            ( { model | selectedCommit = Just commit }, Effect.resetScroll "diff" )

        OpenCommit ->
            ( { model | modal = Just CommitDialog }, Effect.none )

        CloseModal ->
            ( { model | modal = Nothing }, Effect.none )

        SubmitCommit message ->
            ( { model | modal = Nothing }
            , Effect.toast
                (if String.isEmpty message then
                    "(empty commit message)"

                 else
                    "Committed: " ++ message
                )
            )


view : Tui.Context -> Model -> Layout.Layout Msg
view _ model =
    Layout.horizontal
        [ Layout.pane "commits"
            { title = "Commits", width = Layout.fill }
            (Layout.selectableList
                { onSelect = SelectCommit
                , view =
                    \commit ->
                        Tui.Screen.concat
                            [ Tui.Screen.text commit.sha |> Tui.Screen.dim
                            , Tui.Screen.text " "
                            , Tui.Screen.text commit.message
                            ]
                }
                sampleCommits
            )
        , Layout.pane "diff"
            { title = "Diff", width = Layout.fillPortion 2 }
            (Layout.content
                (model.selectedCommit
                    |> Maybe.map (\c -> diffForCommit c.sha)
                    |> Maybe.withDefault ""
                    |> String.lines
                    |> List.map Tui.Screen.text
                )
            )
        ]


bindings : { focusedPane : Maybe String } -> Model -> List (Layout.Group Msg)
bindings _ _ =
    [ Layout.group "Global"
        [ Layout.charBinding 'c' "Commit" OpenCommit ]
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

        Nothing ->
            Nothing


miniGitTest : TuiTest.TuiTest (Layout.FrameworkModel Model Msg) (Layout.FrameworkMsg Msg)
miniGitTest =
    TuiTest.start BackendTaskTest.init miniGitProgram
