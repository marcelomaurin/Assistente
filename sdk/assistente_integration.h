#ifndef ASSISTENTE_INTEGRATION_H
#define ASSISTENTE_INTEGRATION_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define ASSISTENTE_BUFFER_BYTES 1048577u
/* cdecl, UTF-8, caller-owned memory; application must already be running.
 * 0 = response available (inspect JSON ok); 1 = insufficient buffer, NO send;
 * 2 = missing/out-of-bounds arguments; 3 = validation/transport/protocol failure.
 * Allocate ASSISTENTE_BUFFER_BYTES up front, never probe by resending.
 * Do not automatically retry a transport failure of a mutating action.
 */
__declspec(dllimport) uint32_t __cdecl AssistenteApiVersion(void);
__declspec(dllimport) int32_t __cdecl AssistenteRequestV1(
    const char *host, uint16_t port, const char *token, const char *request,
    char *output, uint32_t capacity, uint32_t *required);
#ifdef __cplusplus
}
#endif
#endif
