{-# LANGUAGE DeriveGeneric #-}

module FxSettingData
  ( FxSettingData (..)
  , FxSetting (..)
  , FxLearningSetting (..)
  , FxSettingChart(..)
  , initFxSettingData
  , plusLearningTestTimes
  , plusLearningTestCount
  , initFxSetting
  , initFxSettingChart
  , getLearningTestTimes
  , getLearningTestCount
  , getLogProfit
  , getLogProfitAve
  , setFxSettingData
  , getFxSettingLogResult
  , minFxSettingDelete
  , setHashFxSettingData
  ) where

import           Data.Hashable
import qualified Data.List               as L
import qualified Data.Map                as M
import           Debug.Trace
import qualified FxChartData             as Fcd
import qualified FxTechnicalAnalysisData as Fad
import qualified Ga
import           GHC.Generics            (Generic)
import qualified GlobalSettingData       as Gsd
import qualified Tree                    as Tr

data FxSettingData =
  FxSettingData { fxSettingChart :: FxSettingChart
                , fxSetting      :: FxSetting
                , fxSettingLog   :: M.Map FxSetting (Double, Int)
                } deriving (Show)

data FxSetting =
  FxSetting { settingHash     :: Int
            , prevOpen        :: ([Tr.LeafData (M.Map Int Fad.FxAlgorithmSetting, M.Map Int Fad.FxTechnicalAnalysisData)],
                                   M.Map Int [Tr.LeafData Fad.FxTechnicalAnalysisData])
            , learningSetting :: FxLearningSetting
            , fxTaOpen        :: Fad.FxTechnicalAnalysisSetting
            , fxTaCloseProfit :: Fad.FxTechnicalAnalysisSetting
            , fxTaCloseLoss   :: Fad.FxTechnicalAnalysisSetting
            } deriving (Show, Read, Generic)

data FxSettingChart =
  FxSettingChart { chart            :: [Fcd.FxChartData]
                 , learningTestTime :: Int
                 } deriving (Show)

instance Eq FxSettingData where
  a == b = fxSetting a == fxSetting b

instance Ord FxSettingData where
  compare a b = compare (fxSetting a) (fxSetting b)

instance Eq FxSetting where
  a == b = settingHash a == settingHash b

instance Ord FxSetting where
  compare a b = compare (settingHash a) (settingHash b)

instance Hashable FxSetting where
  hashWithSalt s (FxSetting _ _ _ d e f) = s `hashWithSalt` d `hashWithSalt` e `hashWithSalt` f

data FxLearningSetting =
  FxLearningSetting { learningTestTimes :: Int
                    , learningTestCount :: Int
                    , totalTradeDate    :: Int
                    , numTraderadeDate  :: Int
                    , logProfit         :: Double
                    , logCount          :: Int
                    } deriving (Show, Read, Generic)

initFxSettingData :: FxSettingData
initFxSettingData =
  FxSettingData { fxSettingChart = initFxSettingChart
                , fxSetting      = initFxSetting
                , fxSettingLog   = M.empty
                }


initFxSetting :: FxSetting
initFxSetting =
  FxSetting { settingHash = 0
            , prevOpen            = ([], M.empty)
            , learningSetting = FxLearningSetting { learningTestTimes  = 1
                                                  , learningTestCount  = 1
                                                  , totalTradeDate     = 0
                                                  , numTraderadeDate   = 0
                                                  , logProfit          = 0
                                                  , logCount           = 0
                                                  }
            , fxTaOpen        = Fad.initFxTechnicalAnalysisSetting
            , fxTaCloseProfit = Fad.initFxTechnicalAnalysisSetting
            , fxTaCloseLoss   = Fad.initFxTechnicalAnalysisSetting
            }

initFxSettingChart :: FxSettingChart
initFxSettingChart =
  FxSettingChart { chart            = []
                 , learningTestTime = 0
                 }

plusLearningTestTimes :: FxSettingData -> FxSettingData
plusLearningTestTimes fsd =
  fsd { fxSetting = plusLearningTestTimes2 $ fxSetting fsd
      -- , fxSettingLog = M.mapKeys (\fs -> plusLearningTestTimes2 fs)  $ fxSettingLog fsd
      }

plusLearningTestTimes2 :: FxSetting -> FxSetting
plusLearningTestTimes2 fs =
  fs { learningSetting = (learningSetting fs) {
         learningTestTimes = learningTestTimes (learningSetting fs) + 1
         }
     }

plusLearningTestCount :: Ga.LearningData FxSettingData ->
                         Ga.LearningData FxSettingData
plusLearningTestCount x =
  Ga.LearningData . L.map (\(fsd, p) -> (plusLearningTestCount2 fsd, p)) $ Ga.getLearningData x

plusLearningTestCount2 :: FxSettingData -> FxSettingData
plusLearningTestCount2 fsd =
  fsd { fxSetting = plusLearningTestCount3 $ fxSetting fsd
      -- , fxSettingLog = M.mapKeys (\fs -> plusLearningTestCount3 fs)  $ fxSettingLog fsd
      }

plusLearningTestCount3 :: FxSetting -> FxSetting
plusLearningTestCount3 fs =
  fs { learningSetting = (learningSetting fs) {
         learningTestCount = learningTestCount (learningSetting fs) + 1
         }
     }

getLearningTestTimes :: FxSettingData -> Int
getLearningTestTimes fsd =
  learningTestTimes . learningSetting $ fxSetting fsd

getLearningTestCount :: FxSettingData -> Int
getLearningTestCount fsd =
  (learningTestCount . learningSetting $ fxSetting fsd) * (learningTestTimes . learningSetting $ fxSetting fsd)

getSimChartMax :: FxSettingData -> Int
getSimChartMax fsd =
  L.maximum [ Fad.getSimChartMax . fxTaOpen        $ fxSetting fsd
            , Fad.getSimChartMax . fxTaCloseProfit $ fxSetting fsd
            , Fad.getSimChartMax . fxTaCloseLoss   $ fxSetting fsd
            ]

setFxSetting :: FxSetting -> FxSetting
setFxSetting fts =
  fts { fxTaOpen        = Fad.setFxTechnicalAnalysisSetting $ fxTaOpen fts
      , fxTaCloseProfit = Fad.setFxTechnicalAnalysisSetting $ fxTaCloseProfit fts
      , fxTaCloseLoss   = Fad.setFxTechnicalAnalysisSetting $ fxTaCloseLoss fts
      }

setTreeFunction :: FxSettingData -> FxSettingData
setTreeFunction fs =
  fs { fxSetting = setFxSetting $ fxSetting fs
     , fxSettingLog  = M.mapKeys setFxSetting $ fxSettingLog fs
     }

setFxSettingData :: FxSetting -> M.Map FxSetting (Double, Int) -> FxSettingData
setFxSettingData fs fsl =
  setTreeFunction $ FxSettingData { fxSettingChart = initFxSettingChart
                                  , fxSetting      = fs
                                  , fxSettingLog   = fsl
                                  }

getLogProfit :: FxSettingData -> Double
getLogProfit fsd =
  (logProfit . learningSetting $ fxSetting fsd) * (fromIntegral . logCount . learningSetting $ fxSetting fsd)

getLogProfitAve :: FxSettingData -> Double
getLogProfitAve fsd =
  if (logCount . learningSetting $ fxSetting fsd) == 0
  then 0
  else (logProfit . learningSetting $ fxSetting fsd) / (fromIntegral . logCount . learningSetting $ fxSetting fsd)

minFxSettingDelete :: M.Map FxSetting (Double, Int) -> M.Map FxSetting (Double, Int)
minFxSettingDelete fsl =
  M.fromList . L.take (Gsd.fxSettingLogNum Gsd.gsd) .
  L.sortBy (\(_, (a, a')) (_, (b, b')) -> compare (b * fromIntegral b') (a * fromIntegral a')) $
  M.toList fsl

getFxSettingLogResult :: FxSettingData -> (Double, Int, Double)
getFxSettingLogResult fsd =
  let (p, c) = M.foldl (\(ac, bc) (a, b) -> (ac + a, bc + b)) (0, 0) $ fxSettingLog fsd
  in if c == 0
     then (0, 0, 0)
     else (p, c, p / fromIntegral c)

setHashFxSettingData :: FxSettingData -> FxSettingData
setHashFxSettingData fsd = 
  fsd { fxSetting = (fxSetting fsd)
                    { settingHash = hash (fxSetting fsd)
                    }
      }

