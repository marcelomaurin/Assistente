package br.com.maurinsoft.assistente

/**
 * Política de sessão para comparação biométrica de locutores.
 *
 * Um extrator de embeddings de áudio deve produzir [SpeakerDecision] para
 * cada frase. Esta classe NÃO calcula características vocais.
 */
enum class SpeakerDecision {
    SAME, DIFFERENT, INCONCLUSIVE
}

class SpeakerSessionGate {
    private var sessionActive = false

    /** A primeira frase abre a sessão e é aceita. */
    @Synchronized
    fun shouldForward(decision: SpeakerDecision): Boolean {
        if (!sessionActive) {
            sessionActive = true
            return true
        }
        return decision != SpeakerDecision.DIFFERENT
    }

    @Synchronized
    fun endConversation() {
        sessionActive = false
    }

    @Synchronized
    fun hasActiveConversation(): Boolean = sessionActive
}
