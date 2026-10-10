<?php
namespace App\Mail;

use App\Models\FormationCandidate;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class FormationNotify extends Mailable
{
    use Queueable, SerializesModels;

    public FormationCandidate $candidate;

    /**
     * Create a new message instance.
     *
     * @return void
     */
    public function __construct(FormationCandidate $candidate)
    {
        $this->candidate = $candidate;
    }

    /**
     * Get the message envelope.
     *
     * @return \Illuminate\Mail\Mailables\Envelope
     */
    public function envelope()
    {
        return new Envelope(
            from: new Address('no-reply@gmail.com', 'No Reply'),
            subject: 'Confirmation de votre candidature',
            cc:["info@milleniumhorizon.com", "tech@milleniumhorizon.com"],
        );
    }


    /**
     * Get the message content definition.
     *
     * @return \Illuminate\Mail\Mailables\Content
     */
    public function content()
    {
        return new Content(
            view: 'emails.formation_notify'
        );
    }

    /**
     * Get the attachments for the message.
     *
     * @return array
     */
    public function attachments()
    {
        return [];
    }
}