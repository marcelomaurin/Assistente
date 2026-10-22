package br.com.maurinsoft.assistente

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.os.*
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.net.Socket
import java.util.Locale
import java.util.concurrent.Executors

class RemoteSpeechService : Service(), RecognitionListener {
    companion object {
        const val ACTION_START = "br.com.maurinsoft.assistente.START"
        const val ACTION_STOP = "br.com.maurinsoft.assistente.STOP"
        const val EXTRA_HOST = "host"
        const val EXTRA_PORT = "port"
        private const val CHANNEL = "remote_stt"
    }
    private val handler = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var recognizer: SpeechRecognizer? = null
    private var host = ""
    private var port = 18765
    private var running = false
    private var retryMs = 500L

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        val channel = NotificationChannel(CHANNEL, "Microfone remoto", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        host = intent?.getStringExtra(EXTRA_HOST)?.trim().orEmpty()
        port = intent?.getIntExtra(EXTRA_PORT, 18765) ?: 18765
        if (host.isBlank() || port !in 1..65535 || !SpeechRecognizer.isRecognitionAvailable(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        val notification = Notification.Builder(this, CHANNEL)
            .setContentTitle("Assistente: microfone remoto")
            .setContentText("Reconhecimento de voz ativo")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build()
        startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        running = true
        restartListening()
        return START_STICKY
    }

    private fun restartListening(delay: Long = 0L) {
        handler.postDelayed({
            if (!running) return@postDelayed
            recognizer?.destroy()
            recognizer = SpeechRecognizer.createSpeechRecognizer(this).also {
                it.setRecognitionListener(this)
                val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                }
                it.startListening(request)
            }
        }, delay)
    }

    override fun onResults(results: Bundle) {
        val text = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()?.trim().orEmpty()
        if (text.isNotEmpty()) io.execute {
            try {
                Socket(host, port).use { socket ->
                    socket.getOutputStream().bufferedWriter(Charsets.UTF_8).use { writer ->
                        writer.write(text.replace("\n", " ").replace("\r", " "))
                        writer.newLine()
                        writer.flush()
                    }
                }
            } catch (_: Exception) {
                // A próxima frase tenta novamente; não bloqueia o reconhecimento.
            }
        }
        retryMs = 500L
        restartListening(300)
    }
    override fun onError(error: Int) {
        retryMs = (retryMs * 2).coerceAtMost(5000L)
        restartListening(retryMs)
    }
    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onPartialResults(partialResults: Bundle?) {}
    override fun onEvent(eventType: Int, params: Bundle?) {}
    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        recognizer?.cancel()
        recognizer?.destroy()
        io.shutdownNow()
        super.onDestroy()
    }
}
