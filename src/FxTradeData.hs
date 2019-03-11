module FxTradeData
  ( FxTradeData (..)
  , FxSide (..)
  , FxEnvironment (..)
  , initFxTradeDataCommon
  , getWinRate
  , getEvaluationValue
  , getEvaluationValueList
  ) where

--import Debug.Trace
import qualified Data.Map          as M
import qualified FxChartData             as Fcd
import qualified FxTechnicalAnalysisData as Fad
import qualified GlobalSettingData       as Gsd

data FxTradeData =
  FxTradeData { chart              :: Fcd.FxChartData
              , tradeRate          :: Fcd.FxChartData
              , side               :: FxSide
              , trSuccess          :: Int
              , trFail             :: Int
              , profit             :: Double
              , unrealizedPL       :: Double
              , realizedPL         :: Double
              , chartLength        :: Int
              , tradeDateAve       :: Double
              , environment        :: FxEnvironment
              , bearer             :: String
              , url                :: String
              } deriving (Show, Read)

data FxSide = None | Buy | Sell | Close deriving (Show, Read, Eq)

data FxEnvironment = Backtest | Practice | Production deriving (Show, Read)

instance Num FxTradeData where
  x - y = x { trSuccess          = trSuccess          x - trSuccess          y
            , trFail             = trFail             x - trFail             y
            , profit             = profit             x - profit             y
            , realizedPL         = realizedPL         x - realizedPL         y
            , unrealizedPL       = unrealizedPL       x - unrealizedPL       y
            }
  x + y = x { trSuccess          = trSuccess          x + trSuccess          y
            , trFail             = trFail             x + trFail             y
            , profit             = profit             x + profit             y
            , realizedPL         = realizedPL         x + realizedPL         y
            , unrealizedPL       = unrealizedPL       x + unrealizedPL       y
            }

  fromInteger _ = initFxTradeDataCommon { realizedPL       = 0
                                        , unrealizedPL     = 0
                                        }

instance Eq FxTradeData where
  x == y = getEvaluationValue x == getEvaluationValue y

instance Ord FxTradeData where
  compare x y
    | getEvaluationValue x == getEvaluationValue y    =  EQ
    | getEvaluationValue x <= getEvaluationValue y    =  LT
    | otherwise                                       =  GT


initFxTradeDataCommon :: FxTradeData
initFxTradeDataCommon =
  FxTradeData { chart               = Fcd.initFxChartData
              , tradeRate           = Fcd.initFxChartData
              , side                = None
              , profit              = 0
              , trSuccess           = 0
              , trFail              = 0
              , realizedPL          = Gsd.initalProperty Gsd.gsd
              , unrealizedPL        = Gsd.initalProperty Gsd.gsd
              , chartLength         = 0
              , tradeDateAve        = 0
              , environment         = Backtest
              , bearer              = ""
              , url                 = ""
              }

{-
getEvaluationValue :: FxTradeData -> Double
getEvaluationValue x =
  profit x

getLearningEvaluationValue :: FxTradeData -> Double
getLearningEvaluationValue x =
  profit x
-}

getEvaluationValue :: FxTradeData -> Double
getEvaluationValue x =
  (profit x * unrealizedPL x * getWinRatePure x ^ 4) / (fromIntegral $ chartLength x)
--  (profit x) / (fromIntegral $ chartLength x)
--  profit x / (fromIntegral $ chartLength x)

  --  
{-  
  if getWinRatePure x == 0 || tradeDateAve x == 0
  then 0
  else (profit x * unrealizedPL x) / (getWinRatePure x * tradeDateAve x)
-}

getEvaluationValueList :: [FxTradeData] -> Double
getEvaluationValueList tdlt =
  sum $ map getEvaluationValue tdlt

getWinRatePure :: FxTradeData -> Double
getWinRatePure x =
  if trSuccess x + trFail x == 0
  then 0
  else (fromIntegral $ trSuccess x) / ((fromIntegral $ trSuccess x) + (fromIntegral $ trFail x))

getWinRate :: FxTradeData -> Double
getWinRate x = 100 * getWinRatePure x
