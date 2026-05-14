module Hello exposing
    ( initialModel
    , initialModelWithContext
    , miniGitLayout
    , run
    )

import Ansi.Color
import BackendTask exposing (BackendTask)
import Pages.Script exposing (Script)
import Test.BackendTask as BackendTaskTest
import Test.Tui as TuiTest
import Tui
import Tui.Effect as Effect exposing (Effect)
import Tui.Input as Input
import Tui.Keybinding as Keybinding
import Tui.Layout as Layout
import Tui.Modal
import Tui.Screen
import Tui.Sub


type alias Item =
    { sha : String
    , message : String
    }


type alias Model =
    { layout : Layout.State

    -- , commits : List Commit
    -- , diffContent : String
    , modal : Maybe ModalState

    -- , lastAction : String
    }


type ModalState
    = CommitModal { input : Input.State }
    | HelpModal HelpState


type alias HelpState =
    { mode : HelpMode
    , filter : Input.State
    , selectedIndex : Int
    }


type HelpMode
    = HelpBrowse
    | HelpSearch


type Action
    = DoQuit
    | DoOpenCommit
    | DoOpenHelp


type Msg
    = KeyPressed Tui.Sub.KeyEvent
    | Mouse Tui.Sub.MouseEvent
    | GotPaste String
    | Resized { width : Int, height : Int }
    | SelectCommit Item


run : Script
run =
    Tui.program
        { data = BackendTask.succeed "Hello!"
        , init = \_ -> ( initialModel, Effect.none )
        , update = miniGitUpdate
        , view = miniGitView
        , subscriptions = miniGitSubscriptions
        }
        |> Tui.toScript


initialModel : Model
initialModel =
    { layout = Layout.init |> Layout.focusPane "commits"
    , modal = Nothing
    }


initialModelWithContext : { width : Int, height : Int } -> Model
initialModelWithContext context =
    { initialModel | layout = Layout.withContext context initialModel.layout }


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


miniGitLayout : Model -> Layout.Layout Msg
miniGitLayout model =
    Layout.horizontal
        [ Layout.pane "items"
            { title = "Items", width = Layout.fill }
            (Layout.selectableList
                { onSelect = SelectCommit
                , view = \item -> Tui.Screen.text item.message
                }
                [ { sha = "", message = "Hello!" }
                , { sha = "", message = "Goodbye!" }
                ]
            )
        , Layout.pane "hello"
            { width = Layout.fill
            , title = ""
            }
            (Layout.content
                [ Tui.Screen.text "Hello!"
                ]
            )

        --Layout.pane "commits"
        --    { title = "Commits", width = Layout.fill }
        --    (Layout.selectableList
        --        { onSelect = SelectCommit
        --        , view =
        --            \{ selection } commit ->
        --                case selection of
        --                    Layout.Selected { focused } ->
        --                        Tui.Screen.concat
        --                            [ Tui.Screen.text "▸"
        --                                |> (if focused then
        --                                        Tui.Screen.fg Ansi.Color.yellow
        --
        --                                    else
        --                                        identity
        --                                   )
        --                            , Tui.Screen.text " "
        --                            , Tui.Screen.text commit.sha
        --                                |> (if focused then
        --                                        Tui.Screen.fg Ansi.Color.yellow >> Tui.Screen.bold
        --
        --                                    else
        --                                        Tui.Screen.bold
        --                                   )
        --                            , Tui.Screen.text " "
        --                            , Tui.Screen.text commit.message
        --                            ]
        --                            |> (if focused then
        --                                    Tui.Screen.bg Ansi.Color.blue
        --
        --                                else
        --                                    identity
        --                               )
        --
        --                    Layout.NotSelected ->
        --                        Tui.Screen.concat
        --                            [ Tui.Screen.text " "
        --                            , Tui.Screen.text " "
        --                            , Tui.Screen.text commit.sha |> Tui.Screen.dim
        --                            , Tui.Screen.text " "
        --                            , Tui.Screen.text commit.message
        --                            ]
        --        }
        --        model.commits
        --        |> Layout.withFilterable
        --            (\commit -> commit.sha ++ " " ++ commit.message)
        --            model.commits
        --    )
        --, Layout.pane "diff"
        --    { title = "Diff", width = Layout.fillPortion 2 }
        --    (Layout.content
        --        (model.diffContent
        --            |> String.lines
        --            |> List.map Tui.Screen.text
        --        )
        --    )
        ]


miniGitUpdate : Msg -> Model -> ( Model, Effect Msg )
miniGitUpdate msg model =
    case msg of
        Resized context ->
            ( { model | layout = Layout.withContext context model.layout }, Effect.none )

        _ ->
            case model.modal of
                Just (CommitModal modalState) ->
                    case msg of
                        KeyPressed event ->
                            case event.key of
                                Tui.Sub.Escape ->
                                    ( { model | modal = Nothing }, Effect.none )

                                Tui.Sub.Enter ->
                                    ( { model
                                        | modal = Nothing
                                      }
                                    , Effect.none
                                    )

                                _ ->
                                    ( { model | modal = Just (CommitModal { input = Input.update event modalState.input }) }
                                    , Effect.none
                                    )

                        GotPaste pastedText ->
                            ( { model | modal = Just (CommitModal { input = Input.insertText pastedText modalState.input }) }
                            , Effect.none
                            )

                        _ ->
                            ( model, Effect.none )

                Just (HelpModal helpState) ->
                    case msg of
                        KeyPressed event ->
                            case helpState.mode of
                                HelpBrowse ->
                                    case event.key of
                                        Tui.Sub.Escape ->
                                            ( { model | modal = Nothing }, Effect.none )

                                        Tui.Sub.Character '/' ->
                                            ( { model | modal = Just (HelpModal { helpState | mode = HelpSearch }) }, Effect.none )

                                        Tui.Sub.Character 'j' ->
                                            ( { model | modal = Just (HelpModal { helpState | selectedIndex = helpState.selectedIndex + 1 }) }, Effect.none )

                                        Tui.Sub.Arrow Tui.Sub.Down ->
                                            ( { model | modal = Just (HelpModal { helpState | selectedIndex = helpState.selectedIndex + 1 }) }, Effect.none )

                                        Tui.Sub.Character 'k' ->
                                            ( { model | modal = Just (HelpModal { helpState | selectedIndex = max 0 (helpState.selectedIndex - 1) }) }, Effect.none )

                                        Tui.Sub.Arrow Tui.Sub.Up ->
                                            ( { model | modal = Just (HelpModal { helpState | selectedIndex = max 0 (helpState.selectedIndex - 1) }) }, Effect.none )

                                        _ ->
                                            -- Fall through to global bindings
                                            case Keybinding.dispatch [ testGlobalBindings ] event of
                                                Just action ->
                                                    handleAction action { model | modal = Nothing }

                                                Nothing ->
                                                    ( model, Effect.none )

                                HelpSearch ->
                                    case event.key of
                                        Tui.Sub.Escape ->
                                            ( { model | modal = Just (HelpModal { helpState | mode = HelpBrowse }) }, Effect.none )

                                        Tui.Sub.Enter ->
                                            ( { model | modal = Just (HelpModal { helpState | mode = HelpBrowse, selectedIndex = 0 }) }, Effect.none )

                                        _ ->
                                            ( { model | modal = Just (HelpModal { helpState | filter = Input.update event helpState.filter, selectedIndex = 0 }) }, Effect.none )

                        GotPaste pastedText ->
                            case helpState.mode of
                                HelpSearch ->
                                    ( { model | modal = Just (HelpModal { helpState | filter = Input.insertText pastedText helpState.filter, selectedIndex = 0 }) }, Effect.none )

                                HelpBrowse ->
                                    ( model, Effect.none )

                        _ ->
                            ( model, Effect.none )

                Nothing ->
                    case msg of
                        KeyPressed event ->
                            -- Layout handles filter keys (/, typing, Enter, Escape) and
                            -- number keys for pane focus. Check it first.
                            case Layout.handleKeyEvent event (miniGitLayout model) model.layout of
                                ( newLayout, Just layoutMsg, _ ) ->
                                    miniGitUpdate layoutMsg { model | layout = newLayout }

                                ( newLayout, Nothing, True ) ->
                                    ( { model | layout = newLayout }, Effect.none )

                                ( _, Nothing, False ) ->
                                    case Keybinding.dispatch (testActiveBindings model) event of
                                        Just action ->
                                            handleAction action model

                                        Nothing ->
                                            ( model, Effect.none )

                        Mouse mouseEvent ->
                            let
                                ( newLayout, maybeMsg ) =
                                    Layout.handleMouse mouseEvent (Layout.contextOf model.layout) (miniGitLayout model) model.layout
                            in
                            case maybeMsg of
                                Just userMsg ->
                                    miniGitUpdate userMsg { model | layout = newLayout }

                                Nothing ->
                                    ( { model | layout = newLayout }, Effect.none )

                        SelectCommit commit ->
                            ( { model
                                | layout = Layout.resetScroll "diff" model.layout
                              }
                            , Effect.none
                            )

                        _ ->
                            ( model, Effect.none )


handleAction : Action -> Model -> ( Model, Effect Msg )
handleAction action model =
    case action of
        DoQuit ->
            ( model, Effect.exit )

        DoOpenCommit ->
            ( { model | modal = Just (CommitModal { input = Input.init "" }) }, Effect.none )

        DoOpenHelp ->
            ( { model
                | modal =
                    Just
                        (HelpModal
                            { mode = HelpBrowse
                            , filter = Input.init ""
                            , selectedIndex = 0
                            }
                        )
              }
            , Effect.none
            )


miniGitView : Tui.Context -> Model -> Tui.Screen.Screen
miniGitView ctx model =
    let
        layoutState : Layout.State
        layoutState =
            Layout.withContext { width = ctx.width, height = ctx.height } model.layout

        bgRows : List Tui.Screen.Screen
        bgRows =
            Layout.toRows layoutState (miniGitLayout model)

        bottomBar : Tui.Screen.Screen
        bottomBar =
            case Layout.filterStatusBar "commits" model.layout of
                Just filterBar ->
                    filterBar

                Nothing ->
                    Tui.Screen.empty
    in
    (case model.modal of
        Just (CommitModal modalState) ->
            Tui.Modal.overlay
                { title = "Commit"
                , body =
                    [ Tui.Screen.text ""
                    , Input.view { width = 40 } modalState.input
                    , Tui.Screen.text ""
                    ]
                , footer = "Enter: confirm │ Esc: cancel"
                , width = 50
                }
                { width = ctx.width, height = ctx.height }
                bgRows

        Just (HelpModal helpState) ->
            let
                filterText : String
                filterText =
                    Input.text helpState.filter

                groups : List (Keybinding.Group Action)
                groups =
                    testActiveBindings model

                rowCount : Int
                rowCount =
                    Keybinding.helpRowCount filterText groups

                clampedIdx : Int
                clampedIdx =
                    clamp 0 (max 0 (rowCount - 1)) helpState.selectedIndex

                helpBody : List Tui.Screen.Screen
                helpBody =
                    Keybinding.helpRowsWithSelection clampedIdx filterText groups

                searchRow : List Tui.Screen.Screen
                searchRow =
                    case helpState.mode of
                        HelpSearch ->
                            [ Tui.Screen.concat
                                [ Tui.Screen.text "/" |> Tui.Screen.dim
                                , Input.view { width = 40 } helpState.filter
                                ]
                            , Tui.Screen.text ""
                            ]

                        HelpBrowse ->
                            if not (String.isEmpty filterText) then
                                [ Tui.Screen.text ("/" ++ filterText) |> Tui.Screen.dim
                                , Tui.Screen.text ""
                                ]

                            else
                                []

                footer : String
                footer =
                    case helpState.mode of
                        HelpSearch ->
                            "Enter: confirm │ Esc: cancel"

                        HelpBrowse ->
                            "j/k: navigate │ /: search │ Esc: close"
            in
            Tui.Modal.overlay
                { title = "Keybindings"
                , body = searchRow ++ helpBody
                , footer = footer
                , width = 50
                }
                { width = ctx.width, height = ctx.height }
                bgRows

        Nothing ->
            bgRows
    )
        |> (\rows -> Tui.Screen.lines (List.take (List.length rows - 1) rows ++ [ bottomBar ]))


miniGitSubscriptions : Model -> Tui.Sub.Sub Msg
miniGitSubscriptions _ =
    Tui.Sub.batch
        [ Tui.Sub.onKeyPress KeyPressed
        , Tui.Sub.onMouse Mouse
        , Tui.Sub.onPaste GotPaste
        , Tui.Sub.onResize Resized
        ]


testGlobalBindings : Keybinding.Group Action
testGlobalBindings =
    Keybinding.group "Global"
        [ Keybinding.binding (Tui.Sub.Character 'q') "Quit" DoQuit
        , Keybinding.binding (Tui.Sub.Character 'c') "Commit" DoOpenCommit
        , Keybinding.binding (Tui.Sub.Character '?') "Help" DoOpenHelp
        ]


testActiveBindings : Model -> List (Keybinding.Group Action)
testActiveBindings _ =
    [ testGlobalBindings ]
