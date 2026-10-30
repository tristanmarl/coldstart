import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;

// Wraps the ActivityRecording session of one shower. A FitContributor failure is swallowed:
// recording the shower never depends on the optional target_s field.
class ShowerRecorder {
    private var _session as ActivityRecording.Session? = null;
    private var _restField as FitContributor.Field? = null;
    private var _peakField as FitContributor.Field? = null;
    private var _calmField as FitContributor.Field? = null;
    private var _hrvField as FitContributor.Field? = null;
    private var _hrv30Field as FitContributor.Field? = null;

    public function start(targetSec as Number) as Boolean {
        if (_session != null) {
            return false;
        }
        _session = create(true);
        if (_session == null) {
            _session = create(false);
        }
        if (_session == null) {
            return false;
        }
        var session = _session as ActivityRecording.Session;
        createTargetField(session, targetSec);
        try {
            if (session.start()) {
                return true;
            }
            session.discard();
        } catch (error) {
        }
        _session = null;
        return false;
    }

    // preferred: Meditation / Breathing when the device has the constants, else Generic.
    private function create(preferred as Boolean) as ActivityRecording.Session? {
        try {
            var sport = Activity.SPORT_GENERIC;
            var subSport = Activity.SUB_SPORT_GENERIC;
            if (preferred) {
                if (!(Activity has :SPORT_MEDITATION) || !(Activity has :SUB_SPORT_BREATHING)) {
                    return null;
                }
                sport = Activity.SPORT_MEDITATION;
                subSport = Activity.SUB_SPORT_BREATHING;
            }
            return ActivityRecording.createSession({
                :name => "Cold Shower",
                :sport => sport,
                :subSport => subSport
            });
        } catch (error) {
            return null;
        }
    }

    private function createTargetField(session as ActivityRecording.Session, targetSec as Number) as Void {
        try {
            if (!(session has :createField)) {
                return;
            }
            var field = session.createField("target_s", 0, FitContributor.DATA_TYPE_UINT16,
                {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s"});
            field.setData(targetSec);
        } catch (error) {
        }
        // Shock/HRV fields; each created on its own so one failure leaves the others.
        var summary = FitContributor.MESG_TYPE_SESSION;
        _restField = makeField(session, "hr_rest", 1, FitContributor.DATA_TYPE_UINT8, summary, "bpm");
        _peakField = makeField(session, "hr_peak", 2, FitContributor.DATA_TYPE_UINT8, summary, "bpm");
        _calmField = makeField(session, "calm_s", 3, FitContributor.DATA_TYPE_UINT16, summary, "s");
        _hrvField = makeField(session, "hrv_rmssd", 4, FitContributor.DATA_TYPE_UINT16, summary, "ms");
        _hrv30Field = makeField(session, "hrv_30s", 5, FitContributor.DATA_TYPE_UINT16,
            FitContributor.MESG_TYPE_RECORD, "ms");
        setHrv30(null);
    }

    private function makeField(session as ActivityRecording.Session, name as String, id as Number,
                               type as FitContributor.DataType, mesg as Number,
                               units as String) as FitContributor.Field? {
        try {
            return session.createField(name, id, type, {:mesgType => mesg, :units => units});
        } catch (error) {
            return null;
        }
    }

    // Session summary values; null means "not measured" and is written as the FIT invalid value.
    public function setShockSummary(rest as Number?, peak as Number?, calm as Number?,
                                    rmssd as Number?) as Void {
        writeField(_restField, ShockLogic.fitByte(rest));
        writeField(_peakField, ShockLogic.fitByte(peak));
        writeField(_calmField, ShockLogic.fitWord(calm));
        writeField(_hrvField, ShockLogic.fitWord(rmssd));
    }

    // Record field: the closed window's RMSSD for one record, invalid otherwise.
    public function setHrv30(value as Number?) as Void {
        writeField(_hrv30Field, ShockLogic.fitWord(value));
    }

    private function writeField(field as FitContributor.Field?, value as Number) as Void {
        if (field == null) {
            return;
        }
        try {
            (field as FitContributor.Field).setData(value);
        } catch (error) {
        }
    }

    public function hasSession() as Boolean {
        return _session != null;
    }

    public function isRecording() as Boolean {
        return _session != null && (_session as ActivityRecording.Session).isRecording();
    }

    // Stops the clock of the activity (keeps the session open for save or discard).
    public function stop() as Boolean {
        if (_session == null) {
            return false;
        }
        try {
            var session = _session as ActivityRecording.Session;
            return !session.isRecording() || session.stop();
        } catch (error) {
            return false;
        }
    }

    public function save() as Boolean {
        if (_session == null) {
            return false;
        }
        try {
            var session = _session as ActivityRecording.Session;
            if (session.isRecording() && !session.stop()) {
                return false;
            }
            if (!session.save()) {
                return false;
            }
            _session = null;
            return true;
        } catch (error) {
            return false;
        }
    }

    public function discard() as Boolean {
        if (_session == null) {
            return true;
        }
        try {
            var session = _session as ActivityRecording.Session;
            if (session.isRecording() && !session.stop()) {
                return false;
            }
            if (!session.discard()) {
                return false;
            }
            _session = null;
            return true;
        } catch (error) {
            return false;
        }
    }
}
