module FxTrade ( initFxTradeData
               , backTest
               , learning
               , trade
               , gaLearningEvaluate
               , evaluationOk
               , getProfitList
               ) where

import           Control.Monad
import qualified Data.Map                as M
import           Debug.Trace
import qualified FxChartData             as Fcd
import qualified FxMongodb               as Fm
import qualified FxPrint                 as Fp
import qualified FxSetting               as Fs
import qualified FxSettingData           as Fsd
import qualified FxTechnicalAnalysis     as Ta
import qualified FxTechnicalAnalysisData as Fad
import qualified FxTradeData             as Ftd
import qualified GlobalSettingData       as Gsd
import qualified Tree                    as Tr

evaluationOk :: Ftd.FxTradeData -> [Ftd.FxTradeData] -> Bool
evaluationOk tdl tdlt =
  --0 < Ftd.getEvaluationValue tdl && 0 < Ftd.getEvaluationValueList tdlt
  --0 < Ftd.profit tdl && (and $ map (\x -> 0 < Ftd.profit x) tdlt)
  --0 < Ftd.profit tdl && 0 < getProfitList tdlt
  0 < Ftd.getEvaluationValue tdl && (and $ map (\x -> 0 < Ftd.getEvaluationValue x) tdlt)

getProfitList :: [Ftd.FxTradeData] -> Double
getProfitList tdlt =
  sum $ map Ftd.profit tdlt

getQuantityBacktest :: Ftd.FxTradeData -> Double -> Double
getQuantityBacktest td chart = if (fromIntegral (Gsd.maxUnit Gsd.gsd) * chart) / 25 < Ftd.realizedPL td / Gsd.quantityRate Gsd.gsd
                               then (fromIntegral (Gsd.maxUnit Gsd.gsd) * chart) / 25
                               else Ftd.realizedPL td / Gsd.quantityRate Gsd.gsd

getQuantityLearning :: Ftd.FxTradeData -> Double -> Double
getQuantityLearning = getQuantityBacktest -- td chart = Gsd.initalProperty Gsd.gsd -- Ftd.realizedPL td

{-
getQuantityBacktest :: Ftd.FxTradeData -> Double -> Double
getQuantityBacktest  _ _ = Gsd.initalProperty Gsd.gsd / Gsd.quantityRate Gsd.gsd

getQuantityLearning :: Ftd.FxTradeData -> Double -> Double
getQuantityLearning _ _ = Gsd.initalProperty Gsd.gsd / Gsd.quantityRate Gsd.gsd
-}

evaluateProfitInc :: Fad.FxTechnicalAnalysisSetting -> M.Map Int Fad.FxTechnicalAnalysisData -> Bool
evaluateProfitInc fts ftad =
  Tr.evaluateTree fst (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)

evaluateProfitDec :: Fad.FxTechnicalAnalysisSetting -> M.Map Int Fad.FxTechnicalAnalysisData -> Bool
evaluateProfitDec fts ftad =
  Tr.evaluateTree snd (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)

initFxTradeData :: Ftd.FxEnvironment -> Ftd.FxTradeData
initFxTradeData Ftd.Backtest =
  Ftd.initFxTradeDataCommon { Ftd.environment      = Ftd.Backtest
                            , Ftd.bearer           = ""
                            , Ftd.url              = ""
                        }
initFxTradeData Ftd.Practice =
  Ftd.initFxTradeDataCommon { Ftd.environment      = Ftd.Practice
                            , Ftd.bearer           = Gsd.tradePracticeBearer Gsd.gsd
                            , Ftd.url              = Gsd.tradePracticeUrl  Gsd.gsd
                        }
initFxTradeData Ftd.Production =
  Ftd.initFxTradeDataCommon { Ftd.environment      = Ftd.Production
                            , Ftd.bearer           = Gsd.tradeProductionBearer Gsd.gsd
                            , Ftd.url              = Gsd.tradeProductionUrl  Gsd.gsd
                            }

evaluate :: Fad.FxChartTaData ->
            Fsd.FxSettingData ->
            Fsd.FxSettingData ->
            (Ftd.FxTradeData -> Double -> Double) ->
            Bool ->
            Ftd.FxTradeData ->
            (Ftd.FxSide, Ftd.FxSide, Fsd.FxSettingData, Ftd.FxTradeData)
evaluate ctd fsdi fsd f1 forceSell td =
  let cd        = Fad.taChart ctd
      chart     = if Ftd.side td == Ftd.Buy
                  then Fcd.close cd - Gsd.spread Gsd.gsd
                  else if Ftd.side td == Ftd.Sell
                       then Fcd.close cd + Gsd.spread Gsd.gsd
                       else Fcd.close cd
      tradeRate = Fcd.close $ Ftd.tradeRate td
      tradeNo   = Fcd.no $ Ftd.tradeRate td
      tradeDate = Fcd.no cd - tradeNo
      ftado     = Fad.open        ctd
      ftadcp    = Fad.closeProfit ctd
      ftadcl    = Fad.closeLoss   ctd
      fto       = Fsd.fxTaOpen        $ Fsd.fxSetting fsdi
      ftcp      = Fsd.fxTaCloseProfit $ Fsd.fxSetting fsdi
      ftcl      = Fsd.fxTaCloseLoss   $ Fsd.fxSetting fsdi
      lt  = Fs.getLearningTime     fsdi
      ltt = Fs.getLearningTestTime fsdi
      lcd = if 60 * 24 * 20 * 3 < lt + ltt * Gsd.learningTestCount Gsd.gsd * 3
            then lt + ltt * Gsd.learningTestCount Gsd.gsd * 3 -- 60 * 24 * 20 * 3
            else lt + ltt * Gsd.learningTestCount Gsd.gsd * 3
      unrealizedPL
        | Ftd.side td == Ftd.Buy  = Ftd.realizedPL td + 25 * f1 td chart * ((chart / tradeRate) - 1)
        | Ftd.side td == Ftd.Sell = Ftd.realizedPL td + 25 * f1 td chart * (1 - (chart / tradeRate))
        | otherwise = Ftd.realizedPL td
      (position, open)
{-
        | (Ftd.side td == Ftd.None ||
           (Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Sell)) &&
          evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | (Ftd.side td == Ftd.None ||
           (Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Buy)) &&
          evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)

        | (Ftd.side td == Ftd.None ||
           (0 < tradeRate - chart && Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Sell)) &&
          evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | (Ftd.side td == Ftd.None ||
           (0 < chart - tradeRate && Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Buy)) &&
          evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)


        | (Ftd.side td == Ftd.None ||
           (0 < tradeRate - chart && Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Sell)) &&
          evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | (Ftd.side td == Ftd.None ||
           (0 < chart - tradeRate && Fs.getTradeHoldTime fsd < tradeDate && Ftd.side td == Ftd.Buy)) &&
          evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
-}
        | Ftd.side td == Ftd.None && evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | Ftd.side td == Ftd.None && evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
      (profits, close)
        | open /= Ftd.None && Ftd.side td == Ftd.Buy  = (chart - tradeRate, Ftd.Close)
        | open /= Ftd.None && Ftd.side td == Ftd.Sell = (tradeRate - chart, Ftd.Close)
{-
        | Ftd.side td == Ftd.Buy && (forceSell || Fs.getLearningTestTime fsdi < tradeDate ||
                                     (Fs.getTradeHoldTime fsdi < Fcd.no cd - tradeNo &&
                                      (0 < chart - tradeRate && evaluateProfitDec ftcp ftadcp ||
                                       chart - tradeRate < 0 && evaluateProfitDec ftcl ftadcl ||
                                       Fs.getProfitRate fsdi < chart - tradeRate ||
                                       chart - tradeRate < Fs.getLossCutRate fsdi))) = (chart - tradeRate, Ftd.Buy)
        | Ftd.side td == Ftd.Sell && (forceSell || Fs.getLearningTestTime fsdi < tradeDate ||
                                      (Fs.getTradeHoldTime fsdi < Fcd.no cd - tradeNo &&
                                       (0 < tradeRate - chart && evaluateProfitInc ftcp ftadcp ||
                                        tradeRate - chart < 0 && evaluateProfitInc ftcl ftadcl || 
                                        Fs.getProfitRate fsdi < tradeRate - chart || 
                                        tradeRate - chart < Fs.getLossCutRate fsdi))) = (tradeRate - chart, Ftd.Sell)
-}
        | Ftd.side td == Ftd.Buy &&
          (forceSell ||
            (0 < chart - tradeRate && Fs.getTradeHoldTime fsdi < tradeDate && evaluateProfitDec ftcp ftadcp) ||
            (tradeRate - chart < 0 && Fs.getTradeHoldTime fsdi < tradeDate && evaluateProfitDec ftcl ftadcl) ||
            (chart - tradeRate < 0 && lcd < tradeDate)) = (chart - tradeRate, Ftd.Buy)
        | Ftd.side td == Ftd.Sell &&
          (forceSell ||
            (0 < tradeRate - chart && Fs.getTradeHoldTime fsdi < tradeDate && evaluateProfitInc ftcp ftadcp) ||
            (tradeRate - chart < 0 && Fs.getTradeHoldTime fsdi < tradeDate && evaluateProfitInc ftcl ftadcl) ||
            (tradeRate - chart < 0 && lcd < tradeDate)) = (tradeRate - chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
      fsd' = if close /= Ftd.None
             then let ls  = Fsd.learningSetting $ Fsd.fxSetting fsd
                      ls' = ls { Fsd.trTrade         = Fsd.trTrade ls + 1
                               , Fsd.trTradeDate     = Fsd.trTradeDate ls + (fromIntegral $ tradeDate)
                               , Fsd.trSuccess       = if 0 < profits
                                                       then Fsd.trSuccess ls + 1
                                                       else Fsd.trSuccess ls
                               , Fsd.trFail          = if profits <= 0
                                                       then Fsd.trFail ls + 1
                                                       else Fsd.trFail ls
                               , Fsd.successProfit   = if 0 < profits
                                                       then Fsd.successProfit ls + profits
                                                       else Fsd.successProfit ls
                               , Fsd.failProfit      = if profits <= 0
                                                       then Fsd.failProfit ls +  abs profits
                                                       else Fsd.failProfit ls
                               }
                      alcOpen
                        | 0 < profits = Ta.calcFxalgorithmListCount profits $ Fsd.prevOpen fsd
                        | otherwise   = (Tr.emptyLeafDataMap, M.empty)
                      alcCloseProfit
                        | close == Ftd.Buy  && 0 < profits = Ta.calcFxalgorithmListCount profits $ Ta.makeValidLeafDataMapDec ftcp ftadcp
                        | close == Ftd.Sell && 0 < profits = Ta.calcFxalgorithmListCount profits $ Ta.makeValidLeafDataMapInc ftcp ftadcp
                        | otherwise         = (Tr.emptyLeafDataMap, M.empty)
                      alcCloseLoss
                        | close == Ftd.Buy  && profits <= 0 = Ta.calcFxalgorithmListCount (abs profits) $ Ta.makeValidLeafDataMapDec ftcl ftadcl
                        | close == Ftd.Sell && profits <= 0 = Ta.calcFxalgorithmListCount (abs profits) $ Ta.makeValidLeafDataMapInc ftcl ftadcl
                        | otherwise          = (Tr.emptyLeafDataMap, M.empty)
                      fxTaOpen        = Ta.updateAlgorithmListCount Fad.open
                                        ctd alcOpen        (Fsd.fxTaOpen $ Fsd.fxSetting fsd)
                      fxTaCloseProfit = Ta.updateAlgorithmListCount Fad.closeProfit
                                        ctd alcCloseProfit (Fsd.fxTaCloseProfit $ Fsd.fxSetting fsd)
                      fxTaCloseLoss   = Ta.updateAlgorithmListCount Fad.closeLoss
                                        ctd alcCloseLoss   (Fsd.fxTaCloseLoss $ Fsd.fxSetting fsd)
                  in fsd { Fsd.fxSetting = (Fsd.fxSetting fsd)
                                           { Fsd.learningSetting  = ls'
                                           , Fsd.fxTaOpen         = fxTaOpen       
                                           , Fsd.fxTaCloseProfit  = fxTaCloseProfit
                                           , Fsd.fxTaCloseLoss    = fxTaCloseLoss  
                                           }
                         }
             else fsd
      fsd'' = if open /= Ftd.None
              then fsd' { Fsd.prevOpen = if open == Ftd.Buy
                                         then Ta.makeValidLeafDataMapInc fto ftado
                                         else if open == Ftd.Sell
                                              then Ta.makeValidLeafDataMapDec fto ftado
                                              else ([], M.empty)
                        }
              else fsd'
      td' = td { Ftd.chart     = cd
               , Ftd.tradeRate = if open == Ftd.Buy || open == Ftd.Sell
                                 then Fcd.initFxChartData { Fcd.no  = Fcd.no cd
                                                          , Fcd.close = position
                                                          }
                                 else if close /= Ftd.None
                                      then Fcd.initFxChartData
                                      else Ftd.tradeRate td
               , Ftd.tradeDateAve = if (fromIntegral . Fsd.trTrade . Fsd.learningSetting $ Fsd.fxSetting fsd'') == 0
                                    then 1.0
                                    else (fromIntegral . Fsd.trTradeDate . Fsd.learningSetting $ Fsd.fxSetting fsd'') /
                                         (fromIntegral . Fsd.trTrade . Fsd.learningSetting $ Fsd.fxSetting fsd'')
               , Ftd.side  = if open == Ftd.Buy
                             then Ftd.Buy
                             else if open == Ftd.Sell
                                  then Ftd.Sell
                                  else if close /= Ftd.None
                                       then Ftd.None
                                       else Ftd.side td
               , Ftd.trSuccess  = if close /= Ftd.None && 0 < profits 
                                  then Ftd.trSuccess td + 1
                                  else Ftd.trSuccess td
               , Ftd.trFail     = if close /= Ftd.None && profits <= 0
                                  then Ftd.trFail td + 1
                                  else Ftd.trFail td
               , Ftd.profit     = Ftd.profit td + profits
               , Ftd.realizedPL = if close /= Ftd.None
                                  then unrealizedPL
                                  else Ftd.realizedPL td
               }
      td'' = td' { Ftd.unrealizedPL = if Ftd.side td' == Ftd.Buy
                                      then Ftd.realizedPL td' + 25 * f1 td' chart * ((chart / (Fcd.close $ Ftd.tradeRate td')) - 1)
                                      else if Ftd.side td' == Ftd.Sell
                                           then Ftd.realizedPL td' + 25 * f1 td' chart * (1 - (chart / (Fcd.close $ Ftd.tradeRate td')))
                                           else Ftd.realizedPL td'
                 }
  in (open, close, fsd'', td'')

{-
(x:xcd), ftado, ftadcp, ftadcl [new .. old]
return [old .. new]
-}

makeChartTa :: [Fcd.FxChartData] ->
               M.Map Int [Fad.FxTechnicalAnalysisData] ->
               M.Map Int [Fad.FxTechnicalAnalysisData] ->
               M.Map Int [Fad.FxTechnicalAnalysisData] ->
               [Fad.FxChartTaData] ->
               [Fad.FxChartTaData]
makeChartTa [] _ _ _ ctdl = ctdl
makeChartTa (x:xcd) ftado ftadcp ftadcl ctdl =
  let ftado'  = M.map (dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftado
      ftadcp' = M.map (dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftadcp
      ftadcl' = M.map (dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftadcl
      ctd = Fad.FxChartTaData { Fad.taChart     = x
                              , Fad.open        = M.map (\y -> if null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else head y) ftado'
                              , Fad.closeProfit = M.map (\y -> if null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else head y) ftadcp'
                              , Fad.closeLoss   = M.map (\y -> if null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else head y) ftadcl'
                              }
  in makeChartTa xcd ftado' ftadcp' ftadcl' (ctd:ctdl)

{-
xs [old .. new]
return [old .. new]

Prelude> break (\x -> x `mod` 5 == 0 ) [1..10]
([1,2,3,4],[5,6,7,8,9,10])
-}

makeSimChart :: Int -> [Fcd.FxChartData] -> [Fcd.FxChartData]
makeSimChart _ [] = []
makeSimChart c xs =
  let (chart, xs') = break (\x -> Fcd.no x `mod` c == 0) xs
  in if null xs'
     then let high = maximum $ map (\x -> Fcd.high x) chart
              low  = minimum $ map (\x -> Fcd.low x) chart
              fcd  = (head chart) { Fcd.close = (high + low + (Fcd.close $ head chart)) / 3
                                  }
          in [head xs']
     else if null chart
          then head xs' : makeSimChart c (tail xs')
          else let chart' = head xs' : chart
                   high = maximum $ map (\x -> Fcd.high x) chart'
                   low  = minimum $ map (\x -> Fcd.low x) chart'
                   fcd  = (head xs') { Fcd.close = (high + low + (Fcd.close $ head xs')) / 3
                                     }
               in head xs' : makeSimChart c (tail xs')

{-
xcd [old .. new]
ftado, ftadcp, ftadcl [new .. old]
return [old .. new]
-}

makeChart :: Fsd.FxSettingData -> Int -> [Fcd.FxChartData] -> [Fad.FxChartTaData]
makeChart fsd chartLength xcd  =
  let fs   = Fsd.fxSetting fsd
      ftado  = M.map (\x -> Ta.makeFxTechnicalAnalysisDataList x [] (makeSimChart (Fad.simChart x) xcd) [])
               . Fad.algoSetting $ Fsd.fxTaOpen fs
      ftadcp = M.map (\x -> Ta.makeFxTechnicalAnalysisDataList x [] (makeSimChart (Fad.simChart x) xcd) [])
               . Fad.algoSetting $ Fsd.fxTaCloseProfit fs
      ftadcl = M.map (\x -> Ta.makeFxTechnicalAnalysisDataList x [] (makeSimChart (Fad.simChart x) xcd) [])
               . Fad.algoSetting $ Fsd.fxTaCloseLoss fs
  in makeChartTa (take chartLength $ reverse xcd) ftado ftadcp ftadcl []

backTest :: Int ->
            Ftd.FxTradeData ->
            Fsd.FxSettingData ->
            [Fcd.FxChartData] ->            
            (Bool, Fsd.FxSettingData, Ftd.FxTradeData)
backTest l td fsd xcd =
  let ctdl = makeChart fsd l xcd
      (oc' ,fsd3, td3) = foldl (\(oc, fsd1, td1) ctd -> 
                                  let (open, close, fsd2, td2) = evaluate ctd fsd fsd1 getQuantityBacktest False td1
                                  in (oc || (open /= Ftd.None || close /= Ftd.None), fsd2, td2))
                         (False, fsd, td) ctdl
  in (oc', Fs.checkAlgoSetting fsd3, td3 { Ftd.chartLength = l })

learning :: Fsd.FxSettingData ->
            Ftd.FxTradeData
learning fsd =
  let fc = Fsd.fxChart fsd
      td = initFxTradeData Ftd.Backtest
      ctdl = makeChart fsd (Fsd.chartLength fc) (Fsd.chart fc)
      (_, _, fsd2, td'') = foldl (\(_, _, fsd1, td') ctd -> evaluate ctd fsd fsd1 getQuantityLearning False td')
                           (Ftd.None, Ftd.None, fsd, td) $ init ctdl
      (_, _, _, td''') = evaluate (last ctdl) fsd fsd2 getQuantityLearning True td''
  in if null ctdl
     then td
     else td''' { Ftd.chartLength = Fsd.chartLength fc }


trade :: Ftd.FxTradeData ->
         Fsd.FxSettingData ->
         [Fcd.FxChartData] ->
         (Ftd.FxSide, Ftd.FxSide, Fsd.FxSettingData, Ftd.FxTradeData)

trade td fsd xcd =
  let ctdl = makeChart fsd 1 xcd
      (open, close, fsd', td') = evaluate (last ctdl) fsd fsd getQuantityBacktest False td
  in (open, close, fsd', td')

gaLearningEvaluate :: Fsd.FxSettingData -> (Fsd.FxSettingData, Rational)
gaLearningEvaluate fsd =
  let td = learning fsd
  in (fsd, toRational $ Ftd.getLearningEvaluationValue td)


