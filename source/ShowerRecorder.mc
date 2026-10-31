import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;

// Wraps the ActivityRecording session of one shower. A FitContributor failure is swallowed:
// recording the shower never depends on the optional target_s field.
class ShowerRecorder {
    private var _session as ActivityRecording.Session? = null;

    public function start(targetSec as Number, name as String) as Boolean {
        if (_session != null) {
            return false;
        }
        _session = create(true, name);
        if (_session == null) {
            _session = create(false, name);
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
    private function create(preferred as Boolean, name as String) as ActivityRecording.Session? {
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
                :name => name,
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

    // Resumes recording after a pause (the session stays open while stopped).
    public function resume() as Boolean {
        if (_session == null) {
            return false;
        }
        try {
            var session = _session as ActivityRecording.Session;
            return session.isRecording() || session.start();
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
