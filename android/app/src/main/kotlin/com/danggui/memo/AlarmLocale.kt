package com.danggui.memo

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

internal object AlarmLocale {
    fun contextFor(context: Context, localeTag: String?): Context {
        val normalizedTag = localeTag?.trim().orEmpty()
        if (normalizedTag.isEmpty()) return context
        val locale = Locale.forLanguageTag(normalizedTag)
        if (locale.language.isEmpty()) return context
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(locale)
        return context.createConfigurationContext(configuration)
    }
}
