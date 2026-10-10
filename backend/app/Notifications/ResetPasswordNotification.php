<?php
namespace App\Notifications;

use Illuminate\Notifications\Notification;
use Illuminate\Notifications\Messages\MailMessage;

class ResetPasswordNotification extends Notification
{
    protected $token;

    public function __construct($token)
    {
        $this->token = $token;
    }

    public function via($notifiable)
    {
        return ['mail'];
    }

    public function toMail($notifiable)
    {
        // génère le lien complet
        $url = url("/password/reset/{$this->token}?email=" . urlencode($notifiable->email));

        return (new MailMessage)
            ->subject('Réinitialisation du mot de passe — admin')
            ->view('emails.password', [
                'url' => $url,
                'user' => $notifiable
            ]);
    }
}