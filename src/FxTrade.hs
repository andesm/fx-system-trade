module FxTrade ( initFxTradeData
               , backTest
               , gaLearningEvaluate
               , trade
               , learningEvaluate
               , evaluationOk
               , getChart
               ) where

import qualified Ga
import           Control.Monad
import qualified Data.Map                as M
import qualified Data.List               as L
import           Debug.Trace
import qualified Control.Monad.Random    as R
import qualified FxChartData             as Fcd
import qualified FxMongodb               as Fm
import qualified FxPrint                 as Fp
import qualified FxSettingData           as Fsd
import qualified FxTechnicalAnalysis     as Ta
import qualified FxTechnicalAnalysisData as Fad
import qualified FxTradeData             as Ftd
import qualified GlobalSettingData       as Gsd
import qualified SecretData              as Sd
import qualified Tree                    as Tr

evaluationOk :: [Ftd.FxTradeData] -> Bool
evaluationOk tdlt =
  (L.and $ L.map (\x -> Gsd.initalProperty Gsd.gsd  < Ftd.realizedPL x) tdlt)

getUnitBacktest :: Ftd.FxTradeData -> Double -> Int
getUnitBacktest td chart = let u = truncate $ (25 * (Ftd.realizedPL td / Gsd.quantityRate Gsd.gsd) / chart)
                           in if Ftd.maxUnit td `div` 2 < u
                              then Ftd.maxUnit td `div` 2
                              else u
                                   
getUnitLearning :: Ftd.FxTradeData -> Double -> Int
getUnitLearning td chart = getUnitBacktest td chart

{-  
getUnitBacktest :: Ftd.FxTradeData -> Double -> Int
getUnitBacktest td chart = let u = truncate $ (25 * (Gsd.initalProperty Gsd.gsd / Gsd.quantityRate Gsd.gsd) / chart)
                           in if Ftd.maxUnit td `div` 2 < u
                              then Ftd.maxUnit td `div` 2
                              else u
getUnitLearning :: Ftd.FxTradeData -> Double -> Int
getUnitLearning td chart = truncate $ (25 * Ftd.realizedPL td) / chart

-}


evaluateProfitInc :: Fad.FxTechnicalAnalysisSetting -> M.Map Int Fad.FxTechnicalAnalysisData -> Bool
evaluateProfitInc fts ftad =
  Tr.evaluateTree fst (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)

evaluateProfitDec :: Fad.FxTechnicalAnalysisSetting -> M.Map Int Fad.FxTechnicalAnalysisData -> Bool
evaluateProfitDec fts ftad =
  Tr.evaluateTree snd (Fad.algoSetting fts, ftad) (Fad.techAnaTree fts)

initFxTradeData :: Ftd.FxEnvironment -> Ftd.FxTradeData
initFxTradeData Ftd.Backtest =
  Ftd.initFxTradeDataCommon { Ftd.maxUnit     = Gsd.productionMaxUnit Gsd.gsd
                            , Ftd.coName      = "backtest"
                            , Ftd.environment = Ftd.Backtest
                            , Ftd.bearer      = ""
                            , Ftd.url         = ""
                        }
initFxTradeData Ftd.Practice =
  Ftd.initFxTradeDataCommon { Ftd.maxUnit     = Gsd.practiceMaxUnit Gsd.gsd
                            , Ftd.coName      = "trade_practice"
                            , Ftd.environment = Ftd.Practice
                            , Ftd.bearer      = Sd.tradePracticeBearer Sd.sd
                            , Ftd.url         = Sd.tradePracticeUrl Sd.sd
                        }
initFxTradeData Ftd.Production =
  Ftd.initFxTradeDataCommon { Ftd.maxUnit     = Gsd.productionMaxUnit Gsd.gsd
                            , Ftd.coName      = "trade_production"
                            , Ftd.environment = Ftd.Production
                            , Ftd.bearer      = Sd.tradeProductionBearer Sd.sd
                            , Ftd.url         = Sd.tradeProductionUrl Sd.sd
                            }

evaluateOne :: Fad.FxChartTaData ->
               Fsd.FxSettingData ->
               (Ftd.FxTradeData -> Double -> Int) ->
               Bool ->
               Ftd.FxTradeData ->
               Fsd.FxSetting ->
               (Ftd.FxSide, Ftd.FxSide, Ftd.FxTradeData, Fsd.FxSetting)
evaluateOne ctd fsd f1 forceSell td fs =
  let cd        = Fad.taChart ctd
      chart     = Fcd.close cd
      tradeRate = Fcd.close $ Ftd.tradeRate td
      tradeDate = Fcd.no cd - (Fcd.no $ Ftd.tradeRate td)
      ftado     = Fad.open        ctd
      ftadcp    = Fad.closeProfit ctd
      ftadcl    = Fad.closeLoss   ctd
      fto       = Fsd.fxTaOpen        $ Fsd.fxSetting fsd
      ftcp      = Fsd.fxTaCloseProfit $ Fsd.fxSetting fsd
      ftcl      = Fsd.fxTaCloseLoss   $ Fsd.fxSetting fsd
      lcd = Gsd.maxTradeTime Gsd.gsd
      (position, open)
        | (Ftd.side td == Ftd.None || Ftd.side td == Ftd.Sell) && evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | (Ftd.side td == Ftd.None || Ftd.side td == Ftd.Buy)  && evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
{-
        | Ftd.side td == Ftd.None && evaluateProfitInc fto ftado = (chart, Ftd.Buy)
        | Ftd.side td == Ftd.None && evaluateProfitDec fto ftado = (chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
-}        
      (profits, close)
        | open /= Ftd.None && Ftd.side td == Ftd.Buy  = (chart - tradeRate, Ftd.Buy)
        | open /= Ftd.None && Ftd.side td == Ftd.Sell = (tradeRate - chart, Ftd.Sell)
        | Ftd.side td == Ftd.Buy &&
          (forceSell || lcd < tradeDate ||
           (0 < chart - tradeRate && evaluateProfitDec ftcp ftadcp) ||
           (chart - tradeRate < 0 && evaluateProfitDec ftcl ftadcl)) = (chart - tradeRate, Ftd.Buy)
        | Ftd.side td == Ftd.Sell &&
          (forceSell || lcd < tradeDate ||
            (0 < tradeRate - chart && evaluateProfitInc ftcp ftadcp) ||
            (tradeRate - chart < 0 && evaluateProfitInc ftcl ftadcl)) = (tradeRate - chart, Ftd.Sell)
        | otherwise = (0, Ftd.None)
      fs' = if close /= Ftd.None
            then let ls  = Fsd.learningSetting fs
                     ls' = ls { Fsd.totalTradeDate     = Fsd.totalTradeDate ls + tradeDate
                              , Fsd.numTraderadeDate   = Fsd.numTraderadeDate ls + 1
                              }
                     alcOpen = Ta.calcFxalgorithmListCount profits $ Fsd.prevOpen fs
                     alcCloseProfit
                       | close == Ftd.Buy  && 0 < profits = Ta.calcFxalgorithmListCount profits $ Ta.makeValidLeafDataMapDec ftcp ftadcp
                       | close == Ftd.Sell && 0 < profits = Ta.calcFxalgorithmListCount profits $ Ta.makeValidLeafDataMapInc ftcp ftadcp
                       | otherwise         = (Tr.emptyLeafDataMap, M.empty)
                     alcCloseLoss
                       | close == Ftd.Buy  && profits <= 0 = Ta.calcFxalgorithmListCount (abs profits) $ Ta.makeValidLeafDataMapDec ftcl ftadcl
                       | close == Ftd.Sell && profits <= 0 = Ta.calcFxalgorithmListCount (abs profits) $ Ta.makeValidLeafDataMapInc ftcl ftadcl
                       | otherwise          = (Tr.emptyLeafDataMap, M.empty)
                     fxTaOpen        = Ta.updateAlgorithmListCount Fad.open
                                       ctd alcOpen        $ Fsd.fxTaOpen fs
                     fxTaCloseProfit = Ta.updateAlgorithmListCount Fad.closeProfit
                                       ctd alcCloseProfit $ Fsd.fxTaCloseProfit fs
                     fxTaCloseLoss   = Ta.updateAlgorithmListCount Fad.closeLoss
                                       ctd alcCloseLoss   $ Fsd.fxTaCloseLoss fs
                 in fs { Fsd.learningSetting  = ls'
                       , Fsd.fxTaOpen         = fxTaOpen       
                       , Fsd.fxTaCloseProfit  = fxTaCloseProfit
                       , Fsd.fxTaCloseLoss    = fxTaCloseLoss  
                       }
            else fs
      fs'' = if open /= Ftd.None
             then fs' { Fsd.prevOpen = if open == Ftd.Buy
                                       then Ta.makeValidLeafDataMapInc fto ftado
                                       else if open == Ftd.Sell
                                            then Ta.makeValidLeafDataMapDec fto ftado
                                            else ([], M.empty)
                      }
              else fs'
      td' = td { Ftd.chart     = cd
               , Ftd.tradeRate = if open == Ftd.Buy
                                 then Fcd.initFxChartData { Fcd.no  = Fcd.no cd
                                                          , Fcd.close = position + Gsd.spread Gsd.gsd
                                                          }
                                 else if open == Ftd.Sell
                                      then Fcd.initFxChartData { Fcd.no  = Fcd.no cd
                                                               , Fcd.close = position - Gsd.spread Gsd.gsd
                                                               }
                                      else Ftd.tradeRate td
               , Ftd.unit  = if open /= Ftd.None
                             then f1 td position
                             else if close /= Ftd.None
                                  then 0
                                  else Ftd.unit td
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
                                  then Ftd.realizedPL td + (fromIntegral $ Ftd.unit td) * profits
                                  else Ftd.realizedPL td
               }
  in (open, close, td', fs'')

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
  let ftado'  = M.map (L.dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftado
      ftadcp' = M.map (L.dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftadcp
      ftadcl' = M.map (L.dropWhile (\b -> Fcd.no x < Fcd.no (Fad.chart b))) ftadcl
      ctd = Fad.FxChartTaData { Fad.taChart     = x
                              , Fad.open        = M.map (\y -> if L.null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else L.head y) ftado'
                              , Fad.closeProfit = M.map (\y -> if L.null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else L.head y) ftadcp'
                              , Fad.closeLoss   = M.map (\y -> if L.null y
                                                               then Fad.initFxTechnicalAnalysisData
                                                               else L.head y) ftadcl'
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
  let (chart, xs') = L.break (\x -> Fcd.no x `mod` c == 0) xs
  in if L.null xs'
     then let fcd  = L.head chart
          in [fcd]
     else L.head xs' : makeSimChart c (L.tail xs')

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
  in makeChartTa (L.take chartLength $ L.reverse xcd) ftado ftadcp ftadcl []


backTest :: Int ->
            Ftd.FxTradeData ->
            Fsd.FxSettingData ->
            IO (Fsd.FxSettingData, Ftd.FxTradeData)
backTest n td fsd = do
  let ltt = Ta.getLearningTestTime fsd * Gsd.learningTestCount Gsd.gsd
  fc <- Fm.getChartListSlice (n - Ta.getPrepareTimeAll fsd) (Ta.getPrepareTimeAll fsd + ltt)
  let ctdl = makeChart fsd ltt fc
      fs = Fsd.fxSetting fsd
      (td4, fs4) = L.foldl (\(td2, fs2) ctd -> let (_, _, td3, fs3) = evaluateOne ctd fsd getUnitBacktest False td2 fs2
                                               in (td3, fs3))
                             (td, fs) ctdl
  return $ checkAlgoSetting ltt fsd td4 fs4

checkAlgoSetting :: Int ->
                    Fsd.FxSettingData ->
                    Ftd.FxTradeData ->
                    Fsd.FxSetting ->
                    (Fsd.FxSettingData, Ftd.FxTradeData)
checkAlgoSetting l fsd td fs =
  let td' = td { Ftd.chartLength = l
               }
      fsd' = fsd { Fsd.fxSetting = fs
                                   { Fsd.fxTaOpen        = Ta.checkAlgoSetting $ Fsd.fxTaOpen        fs
                                   , Fsd.fxTaCloseProfit = Ta.checkAlgoSetting $ Fsd.fxTaCloseProfit fs
                                   , Fsd.fxTaCloseLoss   = Ta.checkAlgoSetting $ Fsd.fxTaCloseLoss   fs
                                   }
                 }
  in (fsd', td')

evaluate :: Fsd.FxSettingData -> Int -> [Fcd.FxChartData] -> Ftd.FxTradeData
evaluate fsd ltt fc =
  let td = initFxTradeData Ftd.Backtest
      ctdl = makeChart fsd ltt fc
      (_, _, td2, _) = L.foldl (\(_, _, td1, _) ctd -> evaluateOne ctd fsd getUnitLearning False td1 Fsd.initFxSetting) (Ftd.None, Ftd.None, td, Fsd.initFxSetting) $ L.init ctdl
      (_, _, td3, _) = evaluateOne (L.last ctdl) fsd getUnitLearning True td2 Fsd.initFxSetting
  in if null ctdl
     then td
     else td3 { Ftd.chartLength = ltt }

getChart :: Int -> Fsd.FxSettingData -> IO (Int, [Fcd.FxChartData])
getChart n fsd = do
  let ltt = Ta.getLearningTestTime fsd
      lttp = Ta.getPrepareTimeAll fsd + ltt
  n' <- R.getRandomR(n - lttp * Gsd.learningTestCount Gsd.gsd ^ 2, n - lttp)
  fc <- Fm.getChartListSlice n' lttp
  return (ltt, fc)
  
learningEvaluate :: Int -> Fsd.FxSettingData -> IO [Ftd.FxTradeData]
learningEvaluate n fsd =
  R.mapM (\_ -> do (ltt, fc) <- getChart n fsd
                   return $ evaluate fsd ltt fc) [1 ..  (Gsd.learningTestCount Gsd.gsd)]

trade :: Ftd.FxTradeData ->
         Fsd.FxSettingData ->
         Fcd.FxChartData ->
         IO (Ftd.FxSide, Ftd.FxSide, Ftd.FxTradeData, Fsd.FxSetting)
trade td fsd e = do
  fc <- (L.++) <$> Fm.getChartListSlice (Fcd.no e - 1 - Ta.getPrepareTimeAll fsd) (Ta.getPrepareTimeAll fsd) <*> pure [e]
  let ctdl = makeChart fsd 1 fc
  return $ evaluateOne (L.last ctdl) fsd getUnitBacktest False td Fsd.initFxSetting

gaLearningEvaluate :: Ga.LearningData Fsd.FxSettingData -> Ga.LearningData Fsd.FxSettingData
gaLearningEvaluate (Ga.LearningData ld) =
  Ga.LearningData $ L.map (\(fsd, _) -> let ltt = Fsd.learningTestTime $ Fsd.fxSettingChart fsd
                                            fc = Fsd.chart $ Fsd.fxSettingChart fsd
                                            p = toRational . ((Fsd.getLogProfit fsd + 1) *) . Ftd.getEvaluationValue $ evaluate fsd ltt fc
                                        in (fsd, p)) ld
  


