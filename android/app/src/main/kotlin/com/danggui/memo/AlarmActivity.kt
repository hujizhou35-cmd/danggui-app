package com.danggui.memo

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView

class AlarmActivity : Activity() {
    private lateinit var titleView: TextView
    private lateinit var bodyView: TextView
    private lateinit var textContext: Context
    private var sessionReceiverRegistered = false

    private val sessionReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                refreshContent()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = getColor(R.color.danggui_paper)
        window.navigationBarColor = getColor(R.color.danggui_paper)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        textContext =
            AlarmLocale.contextFor(
                this,
                AlarmStore(this).ringing().firstOrNull()?.localeTag,
            )
        setContentView(createContentView())
        refreshContent()
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(AlarmActions.ACTION_SESSION_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(sessionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(sessionReceiver, filter)
        }
        sessionReceiverRegistered = true
    }

    override fun onResume() {
        super.onResume()
        refreshContent()
    }

    override fun onStop() {
        if (sessionReceiverRegistered) {
            unregisterReceiver(sessionReceiver)
            sessionReceiverRegistered = false
        }
        super.onStop()
    }

    private fun createContentView(): View {
        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(28), dp(72), dp(28), dp(36))
                setBackgroundColor(getColor(R.color.danggui_paper))
            }

        val eyebrow =
            TextView(this).apply {
                text = alarmString(R.string.alarm_screen_eyebrow)
                setTextColor(getColor(R.color.danggui_sage))
                textSize = 18f
                gravity = Gravity.CENTER
                letterSpacing = 0.08f
            }
        root.addView(
            eyebrow,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        titleView =
            TextView(this).apply {
                setTextColor(Color.rgb(50, 47, 43))
                textSize = 34f
                gravity = Gravity.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                setPadding(0, dp(28), 0, dp(16))
            }
        root.addView(
            titleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        bodyView =
            TextView(this).apply {
                setTextColor(Color.rgb(87, 82, 74))
                textSize = 18f
                gravity = Gravity.CENTER
                maxLines = 4
            }
        root.addView(
            bodyView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(1, 0, 1f),
        )

        val snoozeLabel =
            TextView(this).apply {
                text = alarmString(R.string.alarm_snooze_label)
                setTextColor(Color.rgb(87, 82, 74))
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(10))
            }
        root.addView(
            snoozeLabel,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        val snoozeRow =
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }
        listOf(10, 30, 60).forEachIndexed { index, minutes ->
            val button =
                createButton(
                    alarmString(R.string.alarm_minutes, minutes),
                    filled = false,
                ) {
                    AlarmActions.snooze(applicationContext, minutes = minutes)
                    finishAndRemoveTask()
                }
            snoozeRow.addView(
                button,
                LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                    if (index > 0) marginStart = dp(8)
                },
            )
        }
        root.addView(
            snoozeRow,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        val stopButton =
            createButton(alarmString(R.string.alarm_stop_button), filled = true) {
                AlarmActions.stop(applicationContext)
                finishAndRemoveTask()
            }
        root.addView(
            stopButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(60),
            ).apply { topMargin = dp(18) },
        )
        return root
    }

    private fun createButton(text: String, filled: Boolean, onClick: () -> Unit): Button =
        Button(this).apply {
            this.text = text
            isAllCaps = false
            textSize = 17f
            setTextColor(if (filled) Color.WHITE else getColor(R.color.danggui_sage))
            background =
                GradientDrawable().apply {
                    cornerRadius = dp(18).toFloat()
                    if (filled) {
                        setColor(getColor(R.color.danggui_sage))
                    } else {
                        setColor(Color.TRANSPARENT)
                        setStroke(dp(1), getColor(R.color.danggui_sage))
                    }
                }
            setOnClickListener { onClick() }
        }

    private fun refreshContent() {
        val ringing = AlarmStore(this).ringing()
        if (ringing.isEmpty()) {
            finishAndRemoveTask()
            return
        }
        if (ringing.size == 1) {
            val record = ringing.first()
            titleView.text = record.title.ifBlank { alarmString(R.string.alarm_default_title) }
            bodyView.text = record.body.ifBlank { alarmString(R.string.alarm_default_body) }
        } else {
            titleView.text = alarmString(R.string.alarm_multiple_title, ringing.size)
            bodyView.text =
                ringing.take(4).joinToString("\n") {
                    it.title.ifBlank { alarmString(R.string.alarm_default_title) }
                }
        }
    }

    private fun alarmString(resourceId: Int, vararg formatArgs: Any): String =
        textContext.getString(resourceId, *formatArgs)

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
