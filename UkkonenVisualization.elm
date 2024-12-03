module UkkonenVisualization (..) where

import Array exposing (..)
import Html exposing (..)
import Html.Attributes exposing (id, class, disabled)
import Html.Events exposing (onClick)
import Text
import Color exposing (..)
import Dict
import Graphics.Element exposing (..)
import Graphics.Input exposing (..)
import Graphics.Input.Field exposing (..)
import Json.Encode as Json
import List exposing (..)
import Markdown
import String exposing (..)
import Window
import UkkonenTree exposing (..)
import UkkonenAlgorithm exposing (..)


baseColor =
    rgb 57 75 169


lightGrayColor =
    rgb 68 68 68


port tree : Signal Json.Value
port tree =
    Signal.map
        (\( currentStep, steps, string ) ->
            case Array.get currentStep steps of
                Just state ->
                    treeJson
                        state.tree
                        state.activePoint
                        (String.slice
                            0
                            (currentStep + 1)
                            (String.fromList (Array.toList state.string))
                        )

                Nothing ->
                    Json.null
        )
        (Signal.dropRepeats (Signal.map (\m -> ( m.currentStep, m.steps, m.string )) model))


type alias Model =
    { string : String
    , steps : Array UkkonenState
    , currentStep : Int
    , inputField : Content
    }


type Action
    = NoOp
    | InputFieldUpdate Content
    | Build String
    | Back
    | Forward


initialModel =
    { string = ""
    , steps = Array.empty
    , currentStep = 0
    , inputField = noContent
    }


inputString : Signal.Mailbox Content
inputString =
    Signal.mailbox noContent


inputButton : Signal.Mailbox Action
inputButton =
    Signal.mailbox NoOp


inputFieldStyle : Style
inputFieldStyle =
    let
        textDefaultStyle = Text.defaultStyle
    in
        { defaultStyle
            | padding = uniformly -6
            , outline = { color = lightGrayColor, width = uniformly 1, radius = 4 }
            , style = { textDefaultStyle | height = Just 25, color = lightGrayColor }
        }


inputField : Content -> Element
inputField =
    field inputFieldStyle (Signal.message inputString.address) "String..."


inputFieldUpdates : Signal Action
inputFieldUpdates =
    Signal.map (\content -> InputFieldUpdate content) inputString.signal


visualizeButton : Element
visualizeButton =
    Graphics.Input.button (Signal.message inputButton.address NoOp) "build suffix tree"


stringUpdates : Signal Action
stringUpdates =
    Signal.map2
        (\_ inputContent -> Build inputContent.string)
        inputButton.signal
        (Signal.sampleOn inputButton.signal inputString.signal)


leftButton : Bool -> Html
leftButton enabled =
    Html.button [ onClick currentStepUpdates.address Back, disabled <| not enabled ] [ text "< prev" ]


rightButton : Bool -> Html
rightButton enabled =
    Html.button [ onClick currentStepUpdates.address Forward, disabled <| not enabled ] [ text "next >" ]


currentStepUpdates : Signal.Mailbox Action
currentStepUpdates =
    Signal.mailbox NoOp


main : Signal Html
main =
    Signal.map view model


actions : Signal Action
actions =
    Signal.mergeMany [ stringUpdates, currentStepUpdates.signal, inputFieldUpdates ]


model : Signal Model
model =
    Signal.foldp update initialModel actions


update : Action -> Model -> Model
update action model =
    case action of
        InputFieldUpdate content ->
            { model | inputField = content }

        Build string ->
            if string == "" then
                model
            else
                let
                    terminatedString = string ++ "$"

                    steps = Array.fromList (initialState :: UkkonenAlgorithm.steps terminatedString)
                in
                    { model | string = terminatedString, steps = steps, currentStep = 0, inputField = noContent }

        Back ->
            { model | currentStep = max (model.currentStep - 1) 0 }

        Forward ->
            { model | currentStep = min (model.currentStep + 1) ((Array.length model.steps) - 1) }

        NoOp ->
            model


introText : Html
introText =
    Markdown.toHtml """
Un [Suffix tree](https://en.wikipedia.org/wiki/Suffix_tree) (árbol de sufijos) es una estructura de datos especializada que representa todos los sufijos de una cadena de texto en forma de árbol. Es eficiente para resolver problemas como búsqueda de patrones, cálculo de substrings comunes, y comparación de cadenas. Su construcción toma tiempo lineal respecto al tamaño de la cadena, y permite operaciones como búsquedas en tiempo proporcional a la longitud del patrón.

Integrantes:
- Jean Piero Huaylla
- Ian Kevin Condori
- Cesar Gabriel Carranza
"""


view : Model -> Html
view model =
    let
        leftButtonEnabled = model.currentStep > 0

        rightButtonEnabled = model.currentStep < (Array.length model.steps) - 1
    in
        div
            [ id "visualization" ]
            [ div
                [ id "heading" ]
                [ h1 [] [ text "Visualizacion de Suffix Tree (Ukkonen Algorithm)" ]
                , introText
                , div
                    [ id "input-string" ]
                    [ inputField model.inputField |> width 400 |> fromElement
                    , span [ id "input-button-wrapper" ] [ visualizeButton |> width 150 |> fromElement ]
                    ]
                ]
            , div
                [ id "steps-wrapper" ]
                [ div
                    [ id "side-box" ]
                    [ h2 [] [ text <| "Paso " ++ (Basics.toString (model.currentStep + 1)) ++ " de " ++ Basics.toString (Array.length model.steps) ]
                    , div
                        [ id "navigation" ]
                        [ span [ id "left-button-wrapper" ] [ leftButton leftButtonEnabled ]
                        , span [ id "right-button-wrapper" ] [ rightButton rightButtonEnabled ]
                        ]
                    , case Array.get model.currentStep model.steps of
                        Just state ->
                            text ""  -- Reemplaza todo el bloque 'ul' con esto
                        Nothing ->
                            text ""
                    ]
                , div [ id "letter-blocks" ] (letterBlocks model.string model.currentStep model.steps)
                ]
            ]
        


{-| Generate the input string letter blocks
-}
letterBlocks : String -> Int -> Array UkkonenState -> List Html
letterBlocks string currentStep steps =
    case Array.get currentStep steps of
        Just state ->
            List.indexedMap
                (\i c ->
                    let
                        charsAdded = state.charsAdded

                        added =
                            if i < charsAdded then
                                [ class "added" ]
                            else
                                []

                        remainder =
                            if i > charsAdded - state.remainder && i < charsAdded then
                                [ class "remainder" ]
                            else
                                []
                    in
                        div
                            (List.append added remainder)
                            [ text (fromChar c) ]
                )
                (String.toList string)

        Nothing ->
            []


{-| Prints out a JSON representation of the tree
-}
treeJson : UkkonenTree -> ActivePoint -> String -> Json.Value
treeJson tree activePoint string =
    treeJson' 0 tree activePoint string


treeJson' : Int -> UkkonenTree -> ActivePoint -> String -> Json.Value
treeJson' rootId tree activePoint string =
    let
        root = getNode rootId tree

        isActivePoint = (activePoint.nodeId == rootId)
    in
        Json.object
            [ ( "id", Json.int rootId )
            , ( "suffixLink"
              , case root.suffixLink of
                    Just n ->
                        Json.int n

                    Nothing ->
                        Json.null
              )
            , ( "isActivePoint", Json.bool isActivePoint )
            , ( "children"
              , Json.object
                    (List.map
                        (\( c, edge ) ->
                            let
                                labelEnd =
                                    case edge.labelEnd of
                                        Definite l ->
                                            l

                                        EndOfString ->
                                            String.length string
                            in
                                ( fromChar c
                                , Json.object
                                    [ ( "label", Json.string <| String.slice edge.labelStart labelEnd string )
                                    , ( "pointingTo", treeJson' edge.pointingTo tree activePoint string )
                                    , ( "edgeSteps"
                                      , case activePoint.edge of
                                            Just ( ac, edgeSteps ) ->
                                                if (isActivePoint && c == ac) then
                                                    Json.int edgeSteps
                                                else
                                                    Json.null

                                            Nothing ->
                                                Json.null
                                      )
                                    ]
                                )
                        )
                        (Dict.toList root.edges)
                    )
              )
            ]
