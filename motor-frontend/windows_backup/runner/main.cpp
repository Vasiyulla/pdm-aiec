// Runner — Windows entry point for Flutter desktop
#include "flutter_window.h"
#include <optional>
#include "run_loop.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') and make
  // the console application print to stdout/stderr in debug mode.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    // If attaching fails, redirect to nullptr to suppress errors.
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  RunLoop run_loop;

  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1400, 900);
  if (!run_loop.GetWindow().Create(L"Motor Dashboard — Predictive Maintenance",
                                   origin, size)) {
    return EXIT_FAILURE;
  }
  run_loop.GetWindow().SetQuitOnClose(true);
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    run_loop.ProcessMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
