<?php

namespace App\Listeners;

use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Auth\Events\Logout;
use App\Services\UserLogService;
use Illuminate\Http\Request;

class LogUserLogout
{
    protected $logService;

    public function __construct(UserLogService $logService)
    {
        $this->logService = $logService;
    }

    public function handle(Logout $event)
    {
        $service = new UserLogService();
        $service->storeLog(request());
    }
}
