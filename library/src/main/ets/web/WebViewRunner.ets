import { webview } from '@kit.ArkWeb'

/**
 * Some ArkWeb kernels return the script result as a JSON string literal, so the
 * value arrives wrapped in quotes and with escaped quotes inside. This removes
 * that extra layer; plain results pass through unchanged.
 */
export function unwrapScriptResult(result: string): string {
  if (result.length < 2) {
    return result
  }
  if (result.charAt(0) !== '"' || result.charAt(result.length - 1) !== '"') {
    return result
  }
  const inner: string = result.substring(1, result.length - 1)
  if (inner.indexOf('\\') < 0) {
    return inner
  }
  let out: string = ''
  let i: number = 0
  while (i < inner.length) {
    const ch: string = inner.charAt(i)
    if (ch !== '\\') {
      out += ch
      i++
      continue
    }
    const next: string = inner.charAt(i + 1)
    if (next === 'n') {
      out += '\n'
    } else if (next === 'r') {
      out += '\r'
    } else if (next === 't') {
      out += '\t'
    } else if (next === '"') {
      out += '"'
    } else if (next === '\\') {
      out += '\\'
    } else if (next === '/') {
      out += '/'
    } else {
      out += next
    }
    i += 2
  }
  return out
}

/**
 * Runs an adapter script inside the page currently shown by the controller.
 *
 * The controller must belong to a Web component the user has already navigated
 * to the timetable page. Nothing here reads or stores credentials.
 *
 * The call does not throw. When ArkWeb refuses to run the script (detached
 * controller, page already gone) the result is `{"error":"script_failed"}`,
 * which every adapter reports as a warning.
 */
export async function runInWebView(controller: webview.WebviewController, script: string): Promise<string> {
  try {
    const raw: string = await controller.runJavaScript(script)
    return unwrapScriptResult(raw)
  } catch (error) {
    return '{"error":"script_failed"}'
  }
}
