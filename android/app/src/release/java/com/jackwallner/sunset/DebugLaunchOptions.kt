package com.jackwallner.sunset

import android.content.Intent

/** Release and QA builds: launch extras never change anything. */
object DebugLaunchOptions {
    val demoLocation = false
    val screen: String? = null
    val onboardingStep: Int? = null

    @Suppress("UNUSED_PARAMETER")
    fun apply(graph: AppGraph, intent: Intent?) = Unit
}
