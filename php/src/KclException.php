<?php

declare(strict_types=1);

namespace KclLib;

use RuntimeException;

/**
 * Every failure of the native dispatcher — an unknown RPC name, malformed
 * request bytes, or an error raised while executing the KCL program — is
 * reported in-band as a payload starting with the literal "ERROR:" prefix
 * (docs/abi.md §4). The service client strips the prefix and raises this
 * exception with the remainder as the message.
 */
final class KclException extends RuntimeException
{
}
