module SelectionInvariantsTests exposing (suite)

{-| Tests asserting lazygit-style focus/selection invariants:

1.  Within a pane, there is always exactly one selected item — UNLESS the
    pane has 0 items, in which case there is no selection.

2.  Selection auto-clamps when the items list shrinks: if the previously
    selected index now points past the end of the list, `selectedItem`
    returns the new last item (not `Nothing`).

3.  Selection snaps back to the first item when items reappear after the
    list was empty.

4.  Selection is preserved per-pane across focus changes.

5.  There is always exactly one focused pane on render — `Layout.init`
    alone, or a `focusPane` call pointing at a non-existent pane, both
    resolve to the first pane in the layout at render time. This mirrors
    lazygit's `ContextMgr.Current()` fallback to `defaultSideContext()`
    (`pkg/gui/context.go:211`).

These mirror lazygit's `ListCursor.ClampSelection` behavior — see
`pkg/gui/context/traits/list_cursor.go` in the lazygit source.

-}

import Ansi.Color
import BackendTask
import Expect
import Test exposing (Test, describe, test)
import Test.BackendTask as BackendTaskTest
import Test.Tui as TuiTest
import Tui
import Tui.Effect as Effect
import Tui.Layout as Layout
import Tui.Screen
import Tui.Sub


suite : Test
suite =
    describe "Selection invariants (lazygit-style)"
        [ describe "selectedItem honors current item count"
            [ test "empty pane has no selected item" <|
                \() ->
                    let
                        layout : Layout.Layout ()
                        layout =
                            singlePane []
                    in
                    Layout.selectedItem "items" [] layout Layout.init
                        |> Expect.equal Nothing
            , test "non-empty pane selects first item by default" <|
                \() ->
                    let
                        items : List String
                        items =
                            [ "alpha", "bravo", "charlie" ]

                        layout : Layout.Layout ()
                        layout =
                            singlePane items
                    in
                    Layout.selectedItem "items" items layout Layout.init
                        |> Expect.equal (Just "alpha")
            , test "selectedItem respects setSelectedIndex" <|
                \() ->
                    let
                        items : List String
                        items =
                            [ "alpha", "bravo", "charlie" ]

                        layout : Layout.Layout ()
                        layout =
                            singlePane items

                        state : Layout.State
                        state =
                            Layout.init
                                |> Layout.setSelectedIndex "items" 2
                    in
                    Layout.selectedItem "items" items layout state
                        |> Expect.equal (Just "charlie")
            ]
        , describe "auto-clamp when items shrink"
            [ test "selectedItem clamps to new last item when items shrink below the selected index" <|
                \() ->
                    -- Start with 5 items, select index 4 (last). Then items shrink to 2.
                    -- The stored index (4) is now past the end. Lazygit semantics:
                    -- clamp to length-1 (=1), returning "bravo".
                    let
                        layout : Layout.Layout ()
                        layout =
                            singlePane [ "alpha", "bravo" ]

                        state : Layout.State
                        state =
                            Layout.init
                                |> Layout.setSelectedIndex "items" 4
                    in
                    Layout.selectedItem "items" [ "alpha", "bravo" ] layout state
                        |> Expect.equal (Just "bravo")
            , test "selectedItem returns last item when index points exactly at old length" <|
                \() ->
                    let
                        layout : Layout.Layout ()
                        layout =
                            singlePane [ "x", "y", "z" ]

                        state : Layout.State
                        state =
                            Layout.init
                                |> Layout.setSelectedIndex "items" 3
                    in
                    Layout.selectedItem "items" [ "x", "y", "z" ] layout state
                        |> Expect.equal (Just "z")
            , test "selectedItem returns Nothing when items shrink to 0" <|
                \() ->
                    let
                        layout : Layout.Layout ()
                        layout =
                            singlePane []

                        state : Layout.State
                        state =
                            Layout.init
                                |> Layout.setSelectedIndex "items" 3
                    in
                    Layout.selectedItem "items" [] layout state
                        |> Expect.equal Nothing
            ]
        , describe "selection preserved across focus changes"
            [ test "selection survives focusing a different pane and coming back" <|
                \() ->
                    let
                        items : List String
                        items =
                            [ "a", "b", "c", "d" ]

                        layout : Layout.Layout ()
                        layout =
                            twoPanes items

                        state : Layout.State
                        state =
                            Layout.init
                                |> Layout.focusPane "left"
                                |> Layout.setSelectedIndex "left" 2
                                |> Layout.focusPane "right"
                                |> Layout.focusPane "left"
                    in
                    Layout.selectedItem "left" items layout state
                        |> Expect.equal (Just "c")
            ]
        , describe "snap back to first item when items reappear"
            [ test "selecting nothing in empty pane, then items appear → first item selected" <|
                \() ->
                    -- Per lazygit semantics: when an initially-empty pane gains
                    -- items, the selection should land on index 0.
                    let
                        layout : Layout.Layout ()
                        layout =
                            singlePane [ "first", "second" ]

                        -- Stored selectedIndex is the default (0). Items grew from []
                        -- to ["first", "second"]. selectedItem should return "first".
                        state : Layout.State
                        state =
                            Layout.init
                    in
                    Layout.selectedItem "items" [ "first", "second" ] layout state
                        |> Expect.equal (Just "first")
            ]
        , describe "render-time focus fallback (Tui.program path)"
            [ test "Layout.init with no focusPane call: first pane renders with focused chrome" <|
                \() ->
                    -- Reproduces the Hello.elm scenario: when an app uses
                    -- Tui.program directly (not program) and never calls
                    -- focusPane, the first pane should still appear focused.
                    -- Focused panes have green+bold title chrome.
                    TuiTest.expect (focusFallbackApp Nothing)
                        [ TuiTest.ensureViewHasStyled
                            [ TuiTest.fg Ansi.Color.green, TuiTest.bold ]
                            "Items"
                        , TuiTest.expectRunning
                        ]
            , test "focusPane pointing at non-existent pane: first pane still focused on render" <|
                \() ->
                    -- Reproduces the Hello.elm typo: focusPane "commits" when
                    -- the layout has "items" and "hello". Lazygit's
                    -- `Current()` falls back to defaultSideContext when the
                    -- stored context is invalid; we want the same behavior.
                    TuiTest.expect (focusFallbackApp (Just "nonexistent"))
                        [ TuiTest.ensureViewHasStyled
                            [ TuiTest.fg Ansi.Color.green, TuiTest.bold ]
                            "Items"
                        , TuiTest.expectRunning
                        ]
            , test "focusPane pointing at a real pane: that pane is focused (sanity)" <|
                \() ->
                    TuiTest.expect (focusFallbackApp (Just "hello"))
                        [ TuiTest.ensureViewHasStyled
                            [ TuiTest.fg Ansi.Color.green, TuiTest.bold ]
                            "Greeting"
                        , TuiTest.expectRunning
                        ]
            ]
        ]



-- HELPERS


singlePane : List String -> Layout.Layout ()
singlePane items =
    Layout.horizontal
        [ Layout.pane "items"
            { title = "Items", width = Layout.fill }
            (Layout.selectableList
                { onSelect = \_ -> ()
                , view = Tui.Screen.text
                }
                items
            )
        ]


twoPanes : List String -> Layout.Layout ()
twoPanes items =
    Layout.horizontal
        [ Layout.pane "left"
            { title = "Left", width = Layout.fill }
            (Layout.selectableList
                { onSelect = \_ -> ()
                , view = Tui.Screen.text
                }
                items
            )
        , Layout.pane "right"
            { title = "Right", width = Layout.fill }
            (Layout.content [ Tui.Screen.text "right side" ])
        ]



-- TEST APP for render-time focus fallback (mirrors Hello.elm's
-- Tui.program path — no Layout.program involved)


type alias FallbackModel =
    { layout : Layout.State }


type FallbackMsg
    = NoOp


focusFallbackApp : Maybe String -> TuiTest.TuiTest FallbackModel FallbackMsg
focusFallbackApp initialFocus =
    let
        initialLayout : Layout.State
        initialLayout =
            case initialFocus of
                Just paneId ->
                    Layout.init |> Layout.focusPane paneId

                Nothing ->
                    Layout.init
    in
    TuiTest.start BackendTaskTest.init
        { data = BackendTask.succeed ()
        , init = \() -> ( { layout = initialLayout }, Effect.none )
        , update = \_ model -> ( model, Effect.none )
        , view = fallbackView
        , subscriptions = \_ -> Tui.Sub.none
        }


fallbackView : Tui.Context -> FallbackModel -> Tui.Screen.Screen
fallbackView ctx model =
    let
        layoutState : Layout.State
        layoutState =
            Layout.withContext { width = ctx.width, height = ctx.height } model.layout
    in
    Layout.toScreen layoutState fallbackLayout


fallbackLayout : Layout.Layout FallbackMsg
fallbackLayout =
    Layout.horizontal
        [ Layout.pane "items"
            { title = "Items", width = Layout.fill }
            (Layout.selectableList
                { onSelect = \_ -> NoOp
                , view = Tui.Screen.text
                }
                [ "alpha", "bravo" ]
            )
        , Layout.pane "hello"
            { title = "Greeting", width = Layout.fill }
            (Layout.content [ Tui.Screen.text "Hello!" ])
        ]
