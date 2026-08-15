package com.vezzo.budget_flutter.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.vezzo.budget_flutter.MainActivity
import com.vezzo.budget_flutter.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Widget in home: budget rimanente del mese e scorciatoie per registrare
 * una spesa.
 *
 * Non fa rete e non calcola niente: legge lo snapshot che l'app ha già
 * preparato (vedi lib/widget/widget_bridge.dart). Qui gira un
 * BroadcastReceiver, con pochi millisecondi di budget e nessuna garanzia di
 * connessione, quindi ogni numero deve arrivare pronto.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val CHIAVE_SNAPSHOT = "snapshot"

        /** Deve combaciare con WidgetSnapshot.versione lato Dart. */
        private const val VERSIONE_ATTESA = 1

        /** Oltre queste ore i numeri si mostrano attenuati. */
        private const val ORE_PRIMA_DI_ATTENUARE = 12

        private val ID_SLOT = intArrayOf(
            R.id.widget_slot_0,
            R.id.widget_slot_1,
            R.id.widget_slot_2,
            R.id.widget_slot_3,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = leggiSnapshot(widgetData)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_budget)
            disegna(context, views, snapshot)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun leggiSnapshot(widgetData: SharedPreferences): JSONObject? {
        val raw = widgetData.getString(CHIAVE_SNAPSHOT, null) ?: return null
        return try {
            val json = JSONObject(raw)
            // Formato più nuovo di quello che questo widget sa leggere: meglio
            // dire "non so" che mostrare numeri interpretati male.
            if (json.optInt("versione", -1) != VERSIONE_ATTESA) null else json
        } catch (e: Exception) {
            null
        }
    }

    private fun disegna(context: Context, views: RemoteViews, snapshot: JSONObject?) {
        // Tutto il widget è cliccabile: porta all'app.
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )

        if (snapshot == null) {
            mostraMessaggio(views, "Apri l'app per iniziare")
            return
        }

        when (snapshot.optString("stato")) {
            "noAuth" -> {
                mostraMessaggio(views, "Tocca per accedere")
                return
            }
            "noConfig" -> {
                mostraMessaggio(views, "Apri l'app per iniziare")
                return
            }
        }

        val budget = snapshot.optDouble("budgetTotale", 0.0)
        val speso = snapshot.optDouble("speso", 0.0)
        val rimanente = snapshot.optDouble("rimanente", 0.0)
        val aggiornatoAt = snapshot.optLong("aggiornatoAt", 0L)
        val vecchio = eVecchio(aggiornatoAt)

        views.setViewVisibility(R.id.widget_stato, View.GONE)
        views.setViewVisibility(R.id.widget_barra, View.VISIBLE)
        views.setViewVisibility(R.id.widget_slots, View.VISIBLE)

        val nomeWallet = snapshot.optString("walletNome")
        views.setTextViewText(
            R.id.widget_wallet,
            if (nomeWallet.isEmpty()) "BudgetApp" else nomeWallet,
        )
        views.setTextViewText(R.id.widget_aggiornato, etichettaAggiornamento(aggiornatoAt))

        views.setTextViewText(R.id.widget_rimanente, formattaEuro(rimanente))
        views.setTextViewText(
            R.id.widget_sottotitolo,
            "rimanenti su ${formattaEuro(budget)}",
        )

        // Il colore dice più della barra: rosso solo quando il budget è finito.
        // Si tinge il testo e non la barra perché setProgressTintList da
        // RemoteViews esiste solo dall'API 31, e qui il minimo è 26.
        val coloreImporto = when {
            rimanente < 0 -> R.color.widget_error
            vecchio -> R.color.widget_text_secondary
            else -> R.color.widget_text_primary
        }
        views.setTextColor(R.id.widget_rimanente, context.getColor(coloreImporto))

        val percentuale = if (budget > 0) {
            ((speso / budget) * 100).toInt().coerceIn(0, 100)
        } else {
            0
        }
        views.setProgressBar(R.id.widget_barra, 100, percentuale, false)

        disegnaSlot(context, views, snapshot)
    }

    /**
     * Stato senza numeri: si nasconde tutto quello che sarebbe finto e si
     * lascia solo il messaggio. Non si mostrano zeri, che sembrerebbero un
     * dato vero ("hai zero euro rimanenti" non è "non lo so").
     */
    private fun mostraMessaggio(views: RemoteViews, messaggio: String) {
        views.setTextViewText(R.id.widget_wallet, "BudgetApp")
        views.setTextViewText(R.id.widget_aggiornato, "")
        views.setTextViewText(R.id.widget_rimanente, "—")
        views.setTextViewText(R.id.widget_sottotitolo, "")
        views.setViewVisibility(R.id.widget_barra, View.GONE)
        views.setViewVisibility(R.id.widget_slots, View.GONE)
        views.setViewVisibility(R.id.widget_stato, View.VISIBLE)
        views.setTextViewText(R.id.widget_stato, messaggio)
    }

    private fun disegnaSlot(context: Context, views: RemoteViews, snapshot: JSONObject) {
        val slots = snapshot.optJSONArray("slots")

        for (i in ID_SLOT.indices) {
            val slot = if (slots != null && i < slots.length()) slots.optJSONObject(i) else null

            if (slot == null) {
                views.setViewVisibility(ID_SLOT[i], View.GONE)
                continue
            }

            val categoriaId = slot.optString("categoriaId")
            val nome = slot.optString("nome")
            val icona = slot.optString("icona")

            views.setViewVisibility(ID_SLOT[i], View.VISIBLE)
            views.setTextViewText(
                ID_SLOT[i],
                if (icona.isEmpty()) nome else "$icona\n$nome",
            )

            // Ogni slot ha la sua Uri: due PendingIntent con la stessa action
            // e dati diversi restano distinti (Intent.filterEquals guarda i
            // dati), altrimenti tutti gli slot aprirebbero la stessa categoria.
            val uri = Uri.parse("budgetapp://aggiungi?categoria=$categoriaId")
            views.setOnClickPendingIntent(
                ID_SLOT[i],
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
            )
        }
    }

    private fun eVecchio(aggiornatoAt: Long): Boolean {
        if (aggiornatoAt <= 0L) return true
        val ore = (System.currentTimeMillis() - aggiornatoAt) / (1000 * 60 * 60)
        return ore >= ORE_PRIMA_DI_ATTENUARE
    }

    /** "agg. 14:32" oggi, "agg. ieri", "agg. 12 ago" più indietro. */
    private fun etichettaAggiornamento(aggiornatoAt: Long): String {
        if (aggiornatoAt <= 0L) return ""

        val quando = Calendar.getInstance().apply { timeInMillis = aggiornatoAt }
        val oggi = Calendar.getInstance()

        val stessoGiorno =
            quando.get(Calendar.YEAR) == oggi.get(Calendar.YEAR) &&
                quando.get(Calendar.DAY_OF_YEAR) == oggi.get(Calendar.DAY_OF_YEAR)
        if (stessoGiorno) {
            return "agg. " + SimpleDateFormat("HH:mm", Locale.ITALIAN).format(Date(aggiornatoAt))
        }

        oggi.add(Calendar.DAY_OF_YEAR, -1)
        val ieri =
            quando.get(Calendar.YEAR) == oggi.get(Calendar.YEAR) &&
                quando.get(Calendar.DAY_OF_YEAR) == oggi.get(Calendar.DAY_OF_YEAR)
        if (ieri) return "agg. ieri"

        return "agg. " + SimpleDateFormat("d MMM", Locale.ITALIAN).format(Date(aggiornatoAt))
    }

    private fun formattaEuro(valore: Double): String =
        "€" + String.format(Locale.ITALIAN, "%,.0f", valore)
}
