module ModalTests exposing (suite)

import Expect
import Test exposing (Test, describe, test)
import Tui.Modal as Modal
import Tui.Screen


{-| A 60x12 terminal with a small centered modal. The modal occupies the
middle rows; everything to the left of it is background showing through.
-}
term : { width : Int, height : Int }
term =
    { width = 60, height = 12 }


modalConfig : { title : String, body : List Tui.Screen.Screen, footer : String, width : Int }
modalConfig =
    { title = "Keybindings"
    , body =
        [ Tui.Screen.text "j move down"
        , Tui.Screen.text "k move up"
        , Tui.Screen.text "q quit"
        , Tui.Screen.text "esc close"
        ]
    , footer = "esc close"
    , width = 30
    }


{-| The modal covers rows 3..8 (startRow 3, modalHeight 6) for this config.
Row 5 is squarely inside that band.
-}
overlayRow : Int -> Tui.Screen.Screen -> String
overlayRow rowIndex bgRow =
    let
        bgRows : List Tui.Screen.Screen
        bgRows =
            List.range 0 (term.height - 1)
                |> List.map
                    (\i ->
                        if i == rowIndex then
                            bgRow

                        else
                            Tui.Screen.text (String.repeat term.width " ")
                    )
    in
    Modal.overlay modalConfig term bgRows
        |> List.drop rowIndex
        |> List.head
        |> Maybe.map Tui.Screen.toString
        |> Maybe.withDefault ""


suite : Test
suite =
    describe "Tui.Modal.overlay"
        [ test "an empty background row under the modal shows no ellipsis" <|
            \() ->
                -- A blank pane row is padded with spaces out to the full
                -- terminal width. Nothing is actually hidden by the modal,
                -- so no truncation indicator should appear.
                overlayRow 5 (Tui.Screen.text (String.repeat term.width " "))
                    |> String.contains "…"
                    |> Expect.equal False
        , test "a short content row under the modal shows no ellipsis" <|
            \() ->
                -- "alpha" fits entirely to the left of the modal; only the
                -- trailing padding is covered, so there is nothing to elide.
                overlayRow 5 (Tui.Screen.text ("alpha" ++ String.repeat (term.width - 5) " "))
                    |> Expect.all
                        [ String.contains "alpha" >> Expect.equal True
                        , String.contains "…" >> Expect.equal False
                        ]
        , test "a long content row under the modal still shows an ellipsis" <|
            \() ->
                -- Real content genuinely continues under the modal, so the
                -- truncation indicator is correct here.
                overlayRow 5 (Tui.Screen.text (String.repeat term.width "x"))
                    |> String.contains "…"
                    |> Expect.equal True
        ]
