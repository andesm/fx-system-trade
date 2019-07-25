import qualified Ga
import qualified GaFx
import qualified FxSetting                as Fs
import qualified FxSettingData            as Fsd
import qualified FxTradeData              as Ftd
import           System.Environment
import           System.IO

---

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  (command:_) <- getArgs
  case command of
    "statistics"       -> GaFx.statistics
    "debug"            -> GaFx.debug
    "backtest"         -> GaFx.backTest
    "trade-practice"   -> GaFx.trade Ftd.Practice "trade_practice"
    "trade-production" -> GaFx.trade Ftd.Production "trade_production"


