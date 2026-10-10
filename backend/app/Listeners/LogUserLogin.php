<?php

namespace App\Listeners;

use App\Services\UserLogService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Auth\Events\Login;
use Illuminate\Http\Request;

class LogUserLogin
{
    protected $logService;

    public function __construct(UserLogService $logService)
    {
        $this->logService = $logService;
    }

    public function handle(Login $event)
    {
        $service = new UserLogService();
        $service->storeLog(request());
    }
}
